extends WorldEnvironment

@export var sky_rotation_speed:float = 0.02

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var current_rotation:Vector3 = environment.sky_rotation
	current_rotation.y += delta * sky_rotation_speed
	environment.sky_rotation = current_rotation
