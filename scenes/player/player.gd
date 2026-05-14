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
# "Drunk" movement
@export var sway_speed: float = 0.1
@export var sway_rotation: float = 0.05
@export var sway_position: float = 0.01

@export_group("Look Range")
## Initial vertical aim, in degrees. Positive looks up at the sky,
## negative looks down at the ground. This value is ALSO the upper
## bound of the look range — the player can only look down from here.
@export var initial_pitch_degrees: float = 60.0

## Total vertical sweep, in degrees. The player can look down by
## this many degrees from `initial_pitch_degrees`. Default 120° matches
## the original (-45° → +75°) range.
@export var pitch_range_degrees: float = 120.0

@export_group("Walking Audio")
## Per-phase walking streams. Keys are StringName phase IDs
## (&"NIGHT", &"DAWN", &"MIDDAY", &"SUNSET", &"TWILIGHT",
## &"EMPTY_NIGHT", &"SKY"). Phases without an entry fall back to
## default_walking_stream. If that is also null, the stream
## currently assigned to the Walking node is kept.
@export var walking_streams: Dictionary = {}
@export var default_walking_stream: AudioStream
## Target loudness once fully faded in.
@export var walking_volume_db: float = -15.0
@export var walking_fade_duration: float = 0.25
## Minimum XZ speed (m/s) for the loop to count as "walking".
@export var walking_speed_threshold: float = 0.1


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
var _max_pitch: float = 0.0
var _min_pitch: float = 0.0
var _is_walking_audio_playing: bool = false
var _walking_tween: Tween


# -- Onready variables -------------------------------------------------------

## Reference to the InputManager node (child of this player).
## The InputManager translates raw keys → game actions.
@onready var _input_manager: InputManager = $InputManager
@onready var _camera: Camera3D = $CameraHead/Camera3D
@onready var _camera_box: Node3D = $CameraHead
@onready var _camera_box_base_pos: Vector3 = _camera_box.position
@onready var _walking_player: AudioStreamPlayer = $Walking

# -- Virtual callbacks -------------------------------------------------------

func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.5

	# Yaw inherits from the player's editor rotation (so you can face
	# the player in any direction in the scene). Pitch is driven by
	# initial_pitch_degrees so the starting view is explicit and
	# configurable from the Inspector.
	_current_yaw = rotation.y
	_target_yaw = _current_yaw

	var initial_pitch: float = deg_to_rad(initial_pitch_degrees)
	_current_pitch = initial_pitch
	_target_pitch = initial_pitch

	# The starting pitch is the upper bound; pitch_range_degrees below
	# it is the lower bound. Looking up at the sky and the player can
	# only sweep down from there.
	_max_pitch = initial_pitch
	_min_pitch = initial_pitch - deg_to_rad(pitch_range_degrees)

	_walking_player.bus = &"SFX"
	_walking_player.volume_db = -80.0
	GameEventBus.phase_changed.connect(_on_phase_changed)
	_apply_phase_stream(GameStates.current_phase)

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
		_target_pitch = clamp(_target_pitch, _min_pitch, _max_pitch)


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
		_update_walking_audio()
		return

	_process_movement(delta)
	_update_walking_audio()


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


func _update_walking_audio() -> void:
	var horizontal_speed := Vector2(velocity.x, velocity.z).length()
	var is_moving: bool = (
			horizontal_speed > walking_speed_threshold
			and GameStates.can_player_move
	)
	if is_moving and not _is_walking_audio_playing:
		_start_walking_audio()
	elif not is_moving and _is_walking_audio_playing:
		_stop_walking_audio()


func _start_walking_audio() -> void:
	_is_walking_audio_playing = true
	var stream := _walking_player.stream
	if stream == null:
		return
	_walking_player.play(randf() * stream.get_length())
	_tween_walking_volume(walking_volume_db, false)


func _stop_walking_audio() -> void:
	_is_walking_audio_playing = false
	_tween_walking_volume(-80.0, true)


func _tween_walking_volume(target_db: float, stop_after: bool) -> void:
	if _walking_tween and _walking_tween.is_valid():
		_walking_tween.kill()
	_walking_tween = create_tween()
	_walking_tween.tween_property(
			_walking_player, "volume_db", target_db, walking_fade_duration
	)
	if stop_after:
		_walking_tween.tween_callback(_walking_player.stop)


func _apply_phase_stream(phase: StringName) -> void:
	var new_stream: AudioStream = walking_streams.get(
			phase, default_walking_stream
	)
	if new_stream == null or new_stream == _walking_player.stream:
		return

	if not _is_walking_audio_playing:
		_walking_player.stream = new_stream
		return

	# Cross-fade: fade out → swap → restart at random offset → fade in.
	if _walking_tween and _walking_tween.is_valid():
		_walking_tween.kill()
	_walking_tween = create_tween()
	_walking_tween.tween_property(
			_walking_player, "volume_db", -80.0, walking_fade_duration
	)
	_walking_tween.tween_callback(
			func() -> void:
				_walking_player.stream = new_stream
				_walking_player.play(randf() * new_stream.get_length())
	)
	_walking_tween.tween_property(
			_walking_player,
			"volume_db",
			walking_volume_db,
			walking_fade_duration,
	)


# -- Signal callbacks --------------------------------------------------------

func _on_phase_changed(new_phase: StringName) -> void:
	_apply_phase_stream(new_phase)
