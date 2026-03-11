extends Node3D


func _ready() -> void:
	Engine.max_fps = 60


func _process(_delta: float) -> void:
	pass

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_tree().quit()
