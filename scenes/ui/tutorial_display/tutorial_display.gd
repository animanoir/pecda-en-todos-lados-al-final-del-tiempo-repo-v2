extends CanvasLayer
## Shows the current control mappings to the player.
##
## Toggles visibility with the tutorial key (I).
## When the ConfusionSystem remaps controls, this panel
## updates to show the NEW mappings — which is both
## helpful and disorienting.
##
## SCENE STRUCTURE (create in editor):
## TutorialPanel (CanvasLayer) ← this script
## └── PanelContainer
##     └── MarginContainer
##         └── VBoxContainer
##             ├── TitleLabel      "Controles"
##             ├── ForwardLabel    "W: Adelante"
##             ├── BackLabel       "S: Atrás"
##             ├── LeftLabel       "A: Izquierda"
##             ├── RightLabel      "D: Derecha"
##             ├── InteractLabel   "E: Interactuar"
##             └── TutorialLabel   "I: Tutorial"


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

## Human-readable names for each action (in Spanish for the player).
const ACTION_DISPLAY_NAMES: Dictionary = {
	&"move_forward": "Adelante",
	&"move_back": "Atrás",
	&"move_left": "Izquierda",
	&"move_right": "Derecha",
	&"interact": "Interactuar",
	&"tutorial": "Tutorial",
}


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

## Whether the panel is currently shown.
var _is_visible: bool = false

## Stores the current mappings { action_name: key_label }.
## Initialized with defaults, updated on remap.
var _current_mappings: Dictionary = {
	&"move_forward": "W",
	&"move_back": "S",
	&"move_left": "A",
	&"move_right": "D",
	&"interact": "E",
	&"tutorial": "I",
}


# ---------------------------------------------------------------
# Node references
# ---------------------------------------------------------------

## We grab these in _ready(). They point to the Label nodes
## inside the scene tree.
@onready var _panel: PanelContainer = $PanelContainer
@onready var _forward_label: Label = (
		$PanelContainer/MarginContainer/VBoxContainer/ForwardLabel
)
@onready var _back_label: Label = (
		$PanelContainer/MarginContainer/VBoxContainer/BackLabel
)
@onready var _left_label: Label = (
		$PanelContainer/MarginContainer/VBoxContainer/LeftLabel
)
@onready var _right_label: Label = (
		$PanelContainer/MarginContainer/VBoxContainer/RightLabel
)
@onready var _interact_label: Label = (
		$PanelContainer/MarginContainer/VBoxContainer/InteractLabel
)
@onready var _tutorial_label: Label = (
		$PanelContainer/MarginContainer/VBoxContainer/TutorialLabel
)


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	# Start hidden.
	_panel.visible = false
	_is_visible = false

	# Listen for control remaps to update the displayed keys.
	GameEventBus.tutorial_content_changed.connect(
			_on_tutorial_content_changed
	)

	# Set initial text.
	_refresh_labels()


func _unhandled_key_input(event: InputEvent) -> void:
	## Toggle the panel with the I key.
	## We listen for KEY_I directly here instead of going
	## through the InputManager because:
	## 1. The tutorial key is never remapped.
	## 2. The panel is a UI element — UI should handle its
	##    own toggle input.
	## 3. This keeps the TutorialPanel self-contained.
	if not event is InputEventKey:
		return

	# Suppress the toggle while a QTE is running. The QTE pool
	# includes I, and we don't want pressing I as part of the
	# sequence to also open the inventory.
	if GameStates.is_qte_active:
		return

	var key_event := event as InputEventKey

	if key_event.keycode == KEY_I and key_event.pressed and not key_event.echo:
		_toggle()


# ---------------------------------------------------------------
# Public methods
# ---------------------------------------------------------------

func show_panel() -> void:
	## Shows the tutorial panel.
	## Called externally during the opening tutorial moment.
	_is_visible = true
	_panel.visible = true


func hide_panel() -> void:
	## Hides the tutorial panel.
	_is_visible = false
	_panel.visible = false


# ---------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------

func _toggle() -> void:
	## Flips the panel visibility.
	_is_visible = not _is_visible
	_panel.visible = _is_visible


func _refresh_labels() -> void:
	## Updates all labels with the current key mappings.
	_forward_label.text = "%s: %s" % [
		_current_mappings.get(&"move_forward", "?"),
		ACTION_DISPLAY_NAMES.get(&"move_forward", "???"),
	]
	_back_label.text = "%s: %s" % [
		_current_mappings.get(&"move_back", "?"),
		ACTION_DISPLAY_NAMES.get(&"move_back", "???"),
	]
	_left_label.text = "%s: %s" % [
		_current_mappings.get(&"move_left", "?"),
		ACTION_DISPLAY_NAMES.get(&"move_left", "???"),
	]
	_right_label.text = "%s: %s" % [
		_current_mappings.get(&"move_right", "?"),
		ACTION_DISPLAY_NAMES.get(&"move_right", "???"),
	]
	_interact_label.text = "%s: %s" % [
		_current_mappings.get(&"interact", "?"),
		ACTION_DISPLAY_NAMES.get(&"interact", "???"),
	]
	_tutorial_label.text = "%s: %s" % [
		_current_mappings.get(&"tutorial", "?"),
		ACTION_DISPLAY_NAMES.get(&"tutorial", "???"),
	]


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_tutorial_content_changed(new_content: Dictionary) -> void:
	## The ConfusionSystem remapped the controls.
	## new_content format: { &"move_forward": "S", &"move_back": "W", ... }
	_current_mappings = new_content.duplicate()
	_refresh_labels()
