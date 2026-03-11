class_name InputManager
extends Node
## Translates raw keyboard input into game actions.
##
## This is the Command pattern in action: physical keys are
## separated from game actions by this translation layer.
## Early game: W = forward. Late game: W = ???
##
## The ConfusionSystem remaps this translation table,
## which is what creates the disorienting experience.
##
## WHY THIS EXISTS:
## The PlayerController should NEVER read keyboard input
## directly. It only asks the InputManager: "is move_forward
## being held right now?" This way, when controls are remapped,
## the PlayerController doesn't change at all — only the
## translation table changes.
##
## TWO TYPES OF INPUT:
## 1. PRESS actions (interact, tutorial) — fire once on key down.
##    Handled via signal: action_pressed.
## 2. HELD actions (movement) — true while key is held down.
##    Handled via polling: is_action_held().


# ---------------------------------------------------------------
# Signals
# ---------------------------------------------------------------

## A one-shot action was triggered (key pressed, not held).
## Used for interact, tutorial toggle, etc.
## [param action_name] is the translated game action.
signal action_pressed(action_name: StringName)

## The player pressed a key that USED to do something
## before a remap, but no longer does anything.
## This detects confusion — they remember the old controls.
signal wrong_key_pressed(
		expected_action: StringName,
		pressed_key: String,
)


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

## Actions that fire once on press (not held).
## Movement actions are excluded — they use is_action_held().
const PRESS_ACTIONS: Array[StringName] = [
	&"interact",
	&"tutorial",
]


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

## The current translation table.
## Maps physical key scancodes → game action names.
## Example: { KEY_W: &"move_forward", KEY_S: &"move_back" }
var _key_to_action: Dictionary = {}

## Reverse lookup: game action names → physical key scancodes.
## Example: { &"move_forward": KEY_W, &"move_back": KEY_S }
var _action_to_key: Dictionary = {}

## The original mapping the player learned in the tutorial.
## Kept intact so we can detect "confused" presses — when the
## player presses what USED to work but no longer does.
var _original_mapping: Dictionary = {}

## Tracks which ACTIONS are currently held down.
## We track actions (not keys) because that's what the
## PlayerController cares about.
## Example: { &"move_forward": true, &"move_left": true }
var _held_actions: Dictionary = {}


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	_setup_default_mapping()
	_original_mapping = _key_to_action.duplicate()

	# Listen for remap commands from the ConfusionSystem.
	GameEventBus.controls_remapped.connect(_on_controls_remapped)


func _unhandled_key_input(event: InputEvent) -> void:
	## Intercepts raw keyboard input BEFORE anything else.
	##
	## Why _unhandled_key_input and not _input?
	## Because _unhandled means: "only if no UI element consumed
	## this key first." If a future text field or menu catches
	## the key, we don't also react to it. Clean separation.

	if not event is InputEventKey:
		return

	var key_event := event as InputEventKey
	var keycode: int = key_event.keycode

	# Is this key in our translation table?
	if keycode not in _key_to_action:
		# Maybe it USED to be valid — check for confusion.
		if key_event.pressed and not key_event.echo:
			_check_for_confused_press(keycode)
		return

	var action_name: StringName = _key_to_action[keycode]

	if key_event.pressed and not key_event.echo:
		# Key just went down (not a repeat).
		_held_actions[action_name] = true

		# If it's a press-type action, emit the signal.
		if action_name in PRESS_ACTIONS:
			action_pressed.emit(action_name)

	elif not key_event.pressed:
		# Key released.
		_held_actions[action_name] = false


# ---------------------------------------------------------------
# Public methods — for the PlayerController to read
# ---------------------------------------------------------------

func is_action_held(action_name: StringName) -> bool:
	## Is this game action currently being held?
	## The PlayerController calls this every physics frame
	## to build its movement vector.
	##
	## Example:
	##   var forward: float = float(input_manager.is_action_held(&"move_forward"))
	##   var back: float = float(input_manager.is_action_held(&"move_back"))
	##   var input_dir := Vector3(right - left, 0.0, back - forward)
	return _held_actions.get(action_name, false)


func get_movement_vector() -> Vector2:
	## Convenience method that returns a Vector2 representing
	## the current movement input, already normalized.
	## X = right/left, Y = forward/back (Godot convention).
	##
	## This is what the PlayerController reads every frame
	## instead of Input.get_vector().
	var x: float = (
			float(is_action_held(&"move_right"))
			- float(is_action_held(&"move_left"))
	)
	var y: float = (
			float(is_action_held(&"move_back"))
			- float(is_action_held(&"move_forward"))
	)
	var raw := Vector2(x, y)

	if raw.length_squared() > 1.0:
		return raw.normalized()
	return raw


func get_action_key_label(action_name: StringName) -> String:
	## Returns the current key label for a given action.
	## Used by the tutorial panel to show instructions.
	## After a remap, this returns the NEW key for that action.
	if action_name in _action_to_key:
		var keycode: int = _action_to_key[action_name]
		return OS.get_keycode_string(keycode)
	return "?"


func get_all_mappings() -> Dictionary:
	## Returns { action_name: key_label } for tutorial display.
	## Example: { &"move_forward": "W", &"interact": "E", ... }
	var result: Dictionary = {}
	for action_name: StringName in _action_to_key:
		result[action_name] = get_action_key_label(action_name)
	return result


# ---------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------

func _setup_default_mapping() -> void:
	## The "correct" mapping — what the player learns first.
	_key_to_action = {
		KEY_W: &"move_forward",
		KEY_S: &"move_back",
		KEY_A: &"move_left",
		KEY_D: &"move_right",
		KEY_E: &"interact",
		KEY_I: &"tutorial",
	}
	_rebuild_reverse_map()
	_clear_held_actions()


func _rebuild_reverse_map() -> void:
	## Rebuilds the action → key lookup from the key → action table.
	_action_to_key.clear()
	for keycode: int in _key_to_action:
		var action_name: StringName = _key_to_action[keycode]
		_action_to_key[action_name] = keycode


func _clear_held_actions() -> void:
	## Resets all held states to false.
	## Called on remap to prevent "ghost" held actions —
	## if W was held when remap happens, the OLD action
	## that W triggered should stop being "held".
	_held_actions.clear()


func _check_for_confused_press(keycode: int) -> void:
	## Did the player press a key that USED to do something?
	## If W used to mean "move_forward" but after remap it's
	## not in the table anymore, the player is confused.
	## We announce this so the narration system can react.
	if keycode in _original_mapping:
		var original_action: StringName = _original_mapping[keycode]
		var key_label: String = OS.get_keycode_string(keycode)
		wrong_key_pressed.emit(original_action, key_label)
		GameEventBus.player_pressed_wrong_key.emit(
				original_action, key_label
		)


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_controls_remapped(new_map: Dictionary) -> void:
	## Receives a new translation table from the ConfusionSystem.
	## new_map format: { KEY_W: &"move_left", KEY_A: &"move_forward", ... }

	# Clear held actions BEFORE changing the map.
	# This prevents a held key from carrying over its old action.
	_clear_held_actions()

	# Apply the new mapping.
	_key_to_action = new_map.duplicate()
	_rebuild_reverse_map()

	# Build a human-readable version for the tutorial panel.
	var readable_map: Dictionary = get_all_mappings()
	GameEventBus.tutorial_content_changed.emit(readable_map)
