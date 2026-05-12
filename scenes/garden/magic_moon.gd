@tool
extends DirectionalLight3D

@export var moon_speed_x: float = 0.15
@export var moon_speed_y: float = 0.11
@export var moon_amplitude_x: float = 0.05
@export var moon_amplitude_y: float = 0.03

@export_group("Random Z Glitch")
@export var z_min: float = 0.0
@export var z_max: float = 2.5

@export_group("Glitch Timing")
@export var glitch_interval_min: float = 0.5
@export var glitch_interval_max: float = 2.0

var _time_elapsed: float = 0.0
var _base_rotation: Vector3 = Vector3.ZERO
var _glitch_timer: float = 0.0
var _next_glitch_time: float = 0.0


func _ready() -> void:
	_base_rotation = rotation
	_schedule_next_glitch()
	position.z = randf_range(z_min, z_max)

func _process(delta: float) -> void:
	_time_elapsed += delta
	
	var offset_x: float = sin(_time_elapsed * moon_speed_x) * moon_amplitude_x
	
	rotation.x = _base_rotation.x + offset_x
	
	_glitch_timer += delta
	if _glitch_timer >= _next_glitch_time:
		position.z = randf_range(z_min, z_max)
		_glitch_timer = 0.0
		_schedule_next_glitch()


func _schedule_next_glitch() -> void:
	_next_glitch_time = randf_range(glitch_interval_min, glitch_interval_max)
