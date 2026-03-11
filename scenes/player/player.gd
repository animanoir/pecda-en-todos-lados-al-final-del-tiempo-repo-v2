extends CharacterBody3D
## Basic first-person player controller.
##
## Handles mouse-look camera rotation and WASD movement
## with acceleration and deceleration.
##
## IMPORTANT: This does NOT read keyboard input directly.
## It reads movement from the InputManager, which translates
## physical keys to game actions. This is what allows controls
## to be remapped without touching this code.


# -- Export variables --------------------------------------------------------

@export var player_speed: float = 1.5
@export var acceleration: float = 15.0
@export var deceleration: float = 10.0
@export var mouse_sensitivity: float = 0.005

@export_group("Camera Smoothing")
@export var rotation_smoothness: float = 0.1
@export var inertia_strength: float = 0.85

@export_group("Camera Sway")
@export var sway_speed: float = 0.1
@export var sway_rotation: float = 0.05
@export var sway_position: float = 0.01


# -- Private variables -------------------------------------------------------

var _target_velocity := Vector3.ZERO
var _current_velocity := Vector3.ZERO
var _noise := FastNoiseLite.new()
var _sway_time: float = 0.0
var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _current_yaw: float = 0.0
var _current_pitch: float = 0.0
var _rotation_velocity := Vector2.ZERO


# -- Onready variables -------------------------------------------------------

## Reference to the InputManager node (child of this player).
## The InputManager translates raw keys → game actions.
@onready var _input_manager: InputManager = $InputManager
@onready var _camera: Camera3D = $CameraHead/Camera3D
@onready var _camera_box: Node3D = $CameraHead
@onready var _camera_box_base_pos: Vector3 = _camera_box.position


# -- Virtual callbacks -------------------------------------------------------

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_noise.seed = randi()
	_noise.frequency = 0.5


func _process(delta: float) -> void:
	# Block camera rotation and sway when the player can't move.
	if not GameStates.can_player_move:
		return

	# Smooth camera rotation
	_current_yaw = lerp_angle(
			_current_yaw, _target_yaw, rotation_smoothness
	)
	_current_pitch = lerp_angle(
			_current_pitch, _target_pitch, rotation_smoothness
	)
	_rotation_velocity *= inertia_strength
	rotation.y = _current_yaw
	_camera.rotation.x = _current_pitch

	# Camera sway
	_sway_time += delta
	var nx := _noise.get_noise_2d(_sway_time * sway_speed, 0.0)
	var ny := _noise.get_noise_2d(0.0, _sway_time * sway_speed)
	var nz := _noise.get_noise_2d(
			_sway_time * sway_speed, _sway_time * sway_speed
	)
	_camera_box.rotation.x = nx * sway_rotation
	_camera_box.rotation.z = nz * sway_rotation
	_camera_box.position = _camera_box_base_pos + Vector3(
			nx * sway_position, ny * sway_position, nz * sway_position
	)


func _input(event: InputEvent) -> void:
	# Block mouse look when the player can't move.
	if not GameStates.can_player_move:
		return

	if event is InputEventMouseMotion:
		var mouse_motion := Vector2(
				-event.relative.x, -event.relative.y
		) * mouse_sensitivity
		_rotation_velocity = _rotation_velocity.lerp(
				mouse_motion, 1.0 - inertia_strength
		)
		_target_yaw += _rotation_velocity.x
		_target_pitch += _rotation_velocity.y
		_target_pitch = clamp(
				_target_pitch, deg_to_rad(-20.0), deg_to_rad(75.0)
		)


func _physics_process(delta: float) -> void:
	# Gravity always applies, even when frozen.
	if not is_on_floor():
		velocity.y -= (
				ProjectSettings.get_setting("physics/3d/default_gravity")
				* delta
		)

	# Block movement when the player can't move.
	if not GameStates.can_player_move:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	_process_movement(delta)


# -- Private methods ---------------------------------------------------------

func _process_movement(delta: float) -> void:
	## Reads movement from the InputManager (not raw keys!)
	## and applies it with acceleration/deceleration.
	var input_dir: Vector2 = _input_manager.get_movement_vector()

	var forward := -global_transform.basis.z
	forward.y = 0.0
	forward = forward.normalized()

	var right := global_transform.basis.x
	right.y = 0.0
	right = right.normalized()

	var direction := (
			forward * -input_dir.y
			+ right * input_dir.x
	).normalized()

	# Apply the speed multiplier from GameStates.
	# This decreases as deterioration increases.
	var effective_speed: float = (
			player_speed * GameStates.player_speed_multiplier
	)

	if direction.length() > 0.0:
		_target_velocity.x = direction.x * effective_speed
		_target_velocity.z = direction.z * effective_speed
	else:
		_target_velocity.x = 0.0
		_target_velocity.z = 0.0

	var speed := acceleration if direction.length() > 0.0 else deceleration
	_current_velocity = _current_velocity.lerp(
			_target_velocity, delta * speed
	)

	velocity.x = _current_velocity.x
	velocity.z = _current_velocity.z

	move_and_slide()
