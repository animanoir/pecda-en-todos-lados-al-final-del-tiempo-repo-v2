class_name QTEDisplay
extends Control
## Displays a sequence of keys the player must press in order.
##
## Generates random keys from a QWERTY pool, shows them on screen,
## and validates input one key at a time. Each letter has a slightly
## different size and rotation. All letters fade out and shrink over
## the time limit — if time runs out, the QTE fails.

signal qte_completed(success: bool)

const KEY_POOL: Array[int] = [
	KEY_Q, KEY_W, KEY_R, KEY_T, KEY_Y,
	KEY_U, KEY_I, KEY_O, KEY_P,
	KEY_A, KEY_S, KEY_D, KEY_F, KEY_G,
	KEY_H, KEY_J, KEY_K, KEY_L,
	KEY_Z, KEY_X, KEY_C, KEY_V,
	KEY_B, KEY_N, KEY_M,
]

const DEFAULT_LENGTH: int = 5
const KEY_SPACING: int = 24
const RESULT_DISPLAY_TIME: float = 0.5

const COLOR_IDLE := Color(1.0, 1.0, 1.0, 0.35)
const COLOR_ACTIVE := Color(1.0, 1.0, 1.0, 1.0)
const COLOR_CORRECT := Color(0.3, 1.0, 0.4, 1.0)
const COLOR_FAILED := Color(1.0, 0.3, 0.3, 1.0)

const SHRINK_FINAL_SCALE := Vector2(0.3, 0.3)

@export_group("Timing")
@export var time_limit: float = 10.0

@export_group("Letter Appearance")
## Base font size for all letters. Individual sizes vary around this.
@export var key_font_size: int = 36
## Maximum random deviation from the base font size (±).
@export var key_size_variation: int = 8
## Maximum random rotation in degrees (±).
@export var key_rotation_max: float = 5.0

var _sequence: Array[int] = []
var _current_index: int = 0
var _is_active: bool = false
var _key_labels: Array[Label] = []
var _timer_tween: Tween = null

@onready var _key_container: HBoxContainer = $KeyContainer


func _ready() -> void:
	visible = false
	_key_container.add_theme_constant_override("separation", KEY_SPACING)


func _unhandled_input(event: InputEvent) -> void:
	if not _is_active:
		return

	if not (event is InputEventKey and event.is_pressed() and not event.is_echo()):
		return

	var key_event := event as InputEventKey

	get_viewport().set_input_as_handled()

	if key_event.keycode == _sequence[_current_index]:
		_on_correct_key()
	else:
		_on_wrong_key()


## Starts a new QTE sequence. Call this from outside to activate the display.
func start_qte(length: int = DEFAULT_LENGTH) -> void:
	_generate_sequence(length)
	_build_key_display()
	_current_index = 0
	_key_container.modulate.a = 1.0
	_key_container.scale = Vector2.ONE
	_highlight_current_key()

	# Wait one frame so layout resolves and the "E" press doesn't leak in
	await get_tree().process_frame

	_key_container.pivot_offset = _key_container.size * 0.5
	_apply_individual_transforms()
	visible = true
	_start_timer()
	_is_active = true


## Cancels an active QTE immediately. Called when the player looks away.
func cancel_qte() -> void:
	if not _is_active and not visible:
		return

	_kill_timer()
	_is_active = false
	visible = false
	_clear_key_display()


func _generate_sequence(length: int) -> void:
	_sequence.clear()

	for i in range(length):
		var random_index := randi() % KEY_POOL.size()
		_sequence.append(KEY_POOL[random_index])


func _build_key_display() -> void:
	_clear_key_display()

	for i in range(_sequence.size()):
		var label := Label.new()
		var key_name := OS.get_keycode_string(_sequence[i])
		label.text = " %s " % key_name

		var size_offset := randi_range(-key_size_variation, key_size_variation)
		label.add_theme_font_size_override(
				"font_size", key_font_size + size_offset
		)
		label.add_theme_color_override("font_color", COLOR_IDLE)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_key_container.add_child(label)
		_key_labels.append(label)


func _apply_individual_transforms() -> void:
	for label in _key_labels:
		label.pivot_offset = label.size * 0.5
		var angle := randf_range(-key_rotation_max, key_rotation_max)
		label.rotation = deg_to_rad(angle)


func _clear_key_display() -> void:
	for label in _key_labels:
		label.queue_free()
	_key_labels.clear()


func _highlight_current_key() -> void:
	if _current_index < _key_labels.size():
		_key_labels[_current_index].add_theme_color_override(
				"font_color", COLOR_ACTIVE
		)


func _start_timer() -> void:
	_kill_timer()
	_timer_tween = create_tween().set_parallel(true)
	_timer_tween.tween_property(
			_key_container, "modulate:a", 0.0, time_limit
	)
	_timer_tween.tween_property(
			_key_container, "scale", SHRINK_FINAL_SCALE, time_limit
	).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
	_timer_tween.chain().tween_callback(_on_time_expired)


func _kill_timer() -> void:
	if _timer_tween != null and _timer_tween.is_valid():
		_timer_tween.kill()
	_timer_tween = null


func _on_time_expired() -> void:
	if not _is_active:
		return

	_finish(false)


func _on_correct_key() -> void:
	_key_labels[_current_index].add_theme_color_override(
			"font_color", COLOR_CORRECT
	)
	_current_index += 1

	if _current_index >= _sequence.size():
		_kill_timer()
		_finish(true)
	else:
		_highlight_current_key()


func _on_wrong_key() -> void:
	_key_labels[_current_index].add_theme_color_override(
			"font_color", COLOR_FAILED
	)
	_kill_timer()
	_finish(false)


func _finish(success: bool) -> void:
	_is_active = false

	var tween := create_tween()
	tween.tween_interval(RESULT_DISPLAY_TIME)
	tween.tween_callback(_hide_and_emit.bind(success))


func _hide_and_emit(success: bool) -> void:
	visible = false
	_clear_key_display()
	qte_completed.emit(success)
