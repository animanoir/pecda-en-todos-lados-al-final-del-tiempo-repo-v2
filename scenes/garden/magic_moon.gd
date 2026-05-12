extends DirectionalLight3D

@export var moon_speed_x: float = 0.15  # radians per second (oscillation frequency)
@export var moon_speed_y: float = 0.11  # slightly different for organic feel
@export var moon_amplitude_x: float = 0.05  # ~2.8 degrees of swing
@export var moon_amplitude_y: float = 0.03  # ~1.7 degrees of swing
@export var moon_phase_offset: float = 1.57  # ~90 degrees, desyncs x and y

@export_group("Random Z Position")
@export var z_min: float = 0.0
@export var z_max: float = 2.5
@export var position_speed: float = 0.3  # units per second toward target
@export var arrival_threshold: float = 0.05  # how close before picking new target

var _time_elapsed: float = 0.0
var _base_rotation: Vector3 = Vector3.ZERO
var _target_z: float = 0.0


func _ready() -> void:
	_base_rotation = rotation
	_pick_new_target_z()
	position.z = randf_range(z_min, z_max)


func _process(delta: float) -> void:
	_time_elapsed += delta
	
	var offset_x: float = sin(_time_elapsed * moon_speed_x) * moon_amplitude_x
	var offset_y: float = cos(_time_elapsed * moon_speed_y + moon_phase_offset) * moon_amplitude_y
	
	rotation.x = _base_rotation.x + offset_x
	rotation.y = _base_rotation.y + offset_y
	
	position.z = move_toward(position.z, _target_z, position_speed * delta)
	
	if absf(position.z - _target_z) < arrival_threshold:
		_pick_new_target_z()


func _pick_new_target_z() -> void:
	_target_z = randf_range(z_min, z_max)
