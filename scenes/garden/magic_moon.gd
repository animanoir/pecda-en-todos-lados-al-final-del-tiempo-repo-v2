extends DirectionalLight3D

@export var moon_speed_x: float = 0.15  # radians per second (oscillation frequency)
@export var moon_speed_y: float = 0.11  # slightly different for organic feel
@export var moon_amplitude_x: float = 0.05  # ~2.8 degrees of swing
@export var moon_amplitude_y: float = 0.03  # ~1.7 degrees of swing
@export var moon_phase_offset: float = 1.57  # ~90 degrees, desyncs x and y

var _time_elapsed: float = 0.0
var _base_rotation: Vector3 = Vector3.ZERO


func _ready() -> void:
	_base_rotation = rotation


func _process(delta: float) -> void:
	_time_elapsed += delta
	
	var offset_x: float = sin(_time_elapsed * moon_speed_x) * moon_amplitude_x
	var offset_y: float = cos(_time_elapsed * moon_speed_y + moon_phase_offset) * moon_amplitude_y
	
	rotation.x = _base_rotation.x + offset_x
	rotation.y = _base_rotation.y + offset_y
