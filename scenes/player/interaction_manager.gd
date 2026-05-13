class_name InteractionManager
extends Node
## Manages player interaction via RayCast3D, crosshair UI, and QTE.
##
## Detects interactable objects with a raycast, shows a crosshair prompt,
## and triggers a QTE sequence when the player presses interact.
## During QTE, keeps checking the raycast — if the player moves away
## or looks away from the target, the QTE is cancelled.

const CROSSHAIR_DEFAULT: String = "•"
const CROSSHAIR_INTERACT: String = "E"

var _current_target: Node3D = null
var _is_qte_active: bool = false

@onready var _ray: RayCast3D = $"../CameraHead/Camera3D/InteractionRay"
@onready var _crosshair_label: Label = $"../CrosshairUI/Crosshair/CrosshairLabel"
@onready var _qte_display: QTEDisplay = $"../CrosshairUI/QTEDisplay"


func _ready() -> void:
	_crosshair_label.text = CROSSHAIR_DEFAULT
	_qte_display.qte_completed.connect(_on_qte_completed)


func _physics_process(_delta: float) -> void:
	var looking_at := _get_interactable_from_ray()

	if _is_qte_active:
		# Cancel QTE if we lost sight of the target
		if looking_at != _current_target:
			_cancel_qte()
		return

	# Normal mode: update crosshair based on what we see
	if looking_at != null:
		_set_target(looking_at)
	else:
		_clear_target()


func _unhandled_input(event: InputEvent) -> void:
	if _is_qte_active:
		return

	if event.is_action_pressed("interact") and _current_target != null:
		_start_qte()


## Returns the interactable node the ray is hitting, or null.
func _get_interactable_from_ray() -> Node3D:
	if not _ray.is_colliding():
		return null

	var collider: Object = _ray.get_collider()

	if collider is Node3D and collider.is_in_group("interactables"):
		return collider as Node3D

	return null


func _set_target(new_target: Node3D) -> void:
	if _current_target == new_target:
		return

	_current_target = new_target
	_crosshair_label.text = CROSSHAIR_INTERACT


func _clear_target() -> void:
	if _current_target == null:
		return

	_current_target = null
	_crosshair_label.text = CROSSHAIR_DEFAULT


func _start_qte() -> void:
	_is_qte_active = true
	GameStates.is_qte_active = true
	_crosshair_label.visible = false
	_qte_display.start_qte()


func _cancel_qte() -> void:
	_qte_display.cancel_qte()
	_end_qte_mode()
	print("QTE cancelled — lost sight of flower.")


func _end_qte_mode() -> void:
	_is_qte_active = false
	GameStates.is_qte_active = false
	_crosshair_label.visible = true
	_current_target = null


func _on_qte_completed(success: bool) -> void:
	var target := _current_target
	_end_qte_mode()

	if success and is_instance_valid(target):
		if target.has_method("interact"):
			target.interact()
		print("QTE success — flower collected!")
	else:
		print("QTE failed — try again.")
