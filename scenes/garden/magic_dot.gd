class_name MagicDot
extends Node3D
## A floating glowing dot that wanders organically like a butterfly.
##
## Uses simplex noise for smooth direction changes plus a vertical
## sinusoidal wobble for the characteristic flutter. Stays inside a
## spherical zone centered at its parent's origin via a soft return
## force that activates only near the boundary.

@export_group("Motion")
@export var max_speed: float = 1.2
@export var noise_frequency: float = 0.5
@export var noise_strength: float = 2.5
@export var vertical_wobble: float = 0.3
@export var wobble_frequency: float = 3.0

@export_group("Visual")
@export var dot_color: Color = Color(1.0, 0.85, 0.7)
@export var emission_strength: float = 8.0

@export_group("Bounds")
@export var bounds_radius: float = 3.0
@export var return_strength: float = 1.5

var _velocity: Vector3 = Vector3.ZERO
var _noise: FastNoiseLite
var _time: float = 0.0
var _seed_offset: float = 0.0

@onready var _mesh: MeshInstance3D = $MeshInstance3D


func _ready() -> void:
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = noise_frequency
	_seed_offset = randf() * 1000.0
	
	var random_dir := Vector3(
		randf() - 0.5,
		randf() - 0.5,
		randf() - 0.5,
	).normalized()
	_velocity = random_dir * max_speed * 0.5
	
	# Force the emissive material at runtime — bypasses any scene saving issues
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = dot_color
	mat.emission_enabled = true
	mat.emission = dot_color
	mat.emission_energy_multiplier = emission_strength
	_mesh.material_override = mat


func _process(delta: float) -> void:
	_time += delta
	
	var steering := _sample_noise_direction()
	steering.y += sin(_time * wobble_frequency + _seed_offset) * vertical_wobble
	
	var return_force := _compute_return_force()
	var acceleration := steering * noise_strength + return_force
	
	_velocity += acceleration * delta
	_velocity = _velocity.limit_length(max_speed)
	position += _velocity * delta


func _sample_noise_direction() -> Vector3:
	var t := _time + _seed_offset
	return Vector3(
		_noise.get_noise_2d(t, 0.0),
		_noise.get_noise_2d(t, 100.0),
		_noise.get_noise_2d(t, 200.0),
	)


func _compute_return_force() -> Vector3:
	var distance := position.length()
	var soft_zone_start := bounds_radius * 0.7
	
	if distance < soft_zone_start:
		return Vector3.ZERO
	
	var soft_zone_width := bounds_radius * 0.3
	var blend:float = clamp((distance - soft_zone_start) / soft_zone_width, 0.0, 1.0)
	return -position.normalized() * blend * return_strength
