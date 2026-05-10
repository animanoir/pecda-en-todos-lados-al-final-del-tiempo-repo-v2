extends Node3D

var isMouseCaptured:bool = true

func _ready() -> void:
	Engine.max_fps = 60
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and OS.is_debug_build():
		print("esc key pressed")
		if isMouseCaptured:
			freeMouse()
		else:
			captureMouse()
			
func captureMouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	isMouseCaptured = true

func freeMouse():
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	isMouseCaptured = false
