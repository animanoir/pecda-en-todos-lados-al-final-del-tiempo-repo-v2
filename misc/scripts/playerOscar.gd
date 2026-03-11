extends CharacterBody3D

# Add signals near the top of the file
signal glitch_started
signal glitch_ended
signal player_position(_position, _rotation)

@onready var film_grain_shader = $"../SHADER_FilmGrain/TextureRect".material

var glitch_noise = FastNoiseLite.new()

# Variables for the delayed introduction animation
var movement_enabled = false
@export var timer_intro_before_movement: float = 10.0
@onready var lightBulbBuzz = $"../Lights/RedBulb"

# Fade in-out parameters for walking sound
@export var fade_speed: float = 8.0
var target_volume: float = 0.0
var current_volume: float = 0.0
var initial_db: float = 0.0

# Player movement parameters
@export var PLAYER_SPEED = 5.0
@export var ACCELERATION = 15.0
@export var DECELERATION = 10.0
@export var sensivity = 0.1

var target_velocity = Vector3.ZERO
var current_velocity = Vector3.ZERO

# Configuration of visual glitch effect
@export var time_until_max_glitch_increase: float = 10.0
@export var glitch_chance: float = 0.0
var initial_glitch_chance: float = glitch_chance
var max_glitch_chance: float = 0.01
@export var glitch_duration: float = 0.6
@export var flash_duration: float = 0.2
@export_range(0.0, 1.0) var flash_opacity: float = 0.8
@export var color_tint: Color = Color(1.2, 0.8, 0.8)
var original_pitch: float
var current_random_pitch: float = 1.0
var elapsed_time: float = 0.0
var glitch_enabled: bool = false
var has_lighbulb_broken_twice: bool = false

# Variables for the position history system of the glitch
var position_history: Array = []
var history_length: int = 60
var is_glitching: bool = false
var glitch_timer: float = 0.0
var flash_timer: float = 0.0
var returning_from_glitch: bool = false
var original_position: Vector3
var original_rotation: Vector3

# References to glitch noises when glitching is on:
@onready var glitch_sounds: Array = [
	$"GlitchNoises/GlitchNoise1",
	$"GlitchNoises/GlitchNoise2",
	$"GlitchNoises/GlitchNoise3",
	$"GlitchNoises/GlitchNoise4",
	$"GlitchNoises/GlitchNoise5"
]
var available_sound_indices: Array = []

var effect_intensity = 0.0

var flash_overlay = null

@onready var footstep_audio = $AudioCaminando
var is_walking = false
@export var footstep_delay = 1.0

func _ready():
	# Noise configuration for the pitching of the lightbulb.
	glitch_noise.seed = randi()
	glitch_noise.noise_type = FastNoiseLite.TYPE_PERLIN
	glitch_noise.frequency = 0.9
	glitch_noise.fractal_octaves = 2

	# Setup and initializing of delayed movement (for the intro).
	disable_movement()
	var timer = Timer.new()
	timer.wait_time = timer_intro_before_movement
	timer.one_shot = true
	timer.connect("timeout", enable_movement)
	add_child(timer)
	timer.start()
	
	# To enable the glitch after some time so the player can explore the room:
	var glitch_enable_timer = Timer.new()
	glitch_enable_timer.wait_time = 30.0
	glitch_enable_timer.one_shot = true
	glitch_enable_timer.connect("timeout", enable_glitching)
	add_child(glitch_enable_timer)
	glitch_enable_timer.start()
	
	
	# Initial audio configuration.
	if lightBulbBuzz and lightBulbBuzz.get_node("SFX_FocoParpadeando"):
		original_pitch = lightBulbBuzz.get_node("SFX_FocoParpadeando").pitch_scale
	if footstep_audio:
		initial_db = footstep_audio.volume_db
		footstep_audio.volume_db = -80
	
	# Configuration of the audio bus for glitch effects
	for sound in glitch_sounds:
		sound.bus = "GlitchEffects"
	
	# Mouse configuration input.
	Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	
	# Overlay configuration and initialization (for the flash effect during the glitch).
	flash_overlay = ColorRect.new()
	flash_overlay.set_name("FlashOverlay")
	flash_overlay.color = Color(0, 0, 0, 0)
	flash_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	$CameraBox/Camera3D.add_child(flash_overlay)
	

func _process(delta: float) -> void:
	if !has_lighbulb_broken_twice and glitch_enabled:
		increase_glitch_chance(delta)

func _input(event):
	if !movement_enabled:
		return
	if event is InputEventMouseMotion and !is_glitching:
		$CameraBox/Camera3D.rotation_degrees.x -= event.relative.y * sensivity
		$CameraBox/Camera3D.rotation_degrees.x = clamp($CameraBox/Camera3D.rotation_degrees.x, -90, 90)

func _physics_process(delta):
	if !movement_enabled:
		return
	# Apply gravity when not on the floor
	if not is_on_floor():
		velocity.y -= ProjectSettings.get_setting("physics/3d/default_gravity") * delta

	# Management of position history for the glitch
	position_history.push_back({
		"position": global_position,
		"camera_rotation": $CameraBox/Camera3D.rotation
	})
	if position_history.size() > history_length:
		position_history.pop_front()

	if is_glitching:
		process_glitching(delta)
	else:
		if lightBulbBuzz and lightBulbBuzz.get_node("SFX_FocoParpadeando"):
			lightBulbBuzz.get_node("SFX_FocoParpadeando").pitch_scale = original_pitch
		if randf() < glitch_chance and position_history.size() > 0 and glitch_enabled:
			start_glitch()
		process_movement(delta)
		# Rotate player to match camera direction
		# rotate_to_camera_direction()

func process_movement(delta):
	if !movement_enabled:
		return

	# The := means TYPE INFERENCE, kind of TypeScript.
	var input_dir := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	var camera_forward = $CameraBox/Camera3D.global_transform.basis.z
	camera_forward.y = 0
	camera_forward = camera_forward.normalized()
	var camera_right = $CameraBox/Camera3D.global_transform.basis.x
	camera_right.y = 0
	camera_right = camera_right.normalized()
	var direction = (camera_forward * input_dir.y + camera_right * input_dir.x).normalized()
	
	is_walking = direction.length() > 0 and is_on_floor()
	
	if direction:
		target_velocity.x = direction.x * PLAYER_SPEED
		target_velocity.z = direction.z * PLAYER_SPEED
	else:
		target_velocity.x = 0
		target_velocity.z = 0
	
	var speed = ACCELERATION if direction else DECELERATION
	current_velocity = current_velocity.lerp(target_velocity, delta * speed)
	velocity.x = current_velocity.x
	velocity.z = current_velocity.z
	
	process_footsteps(delta)
	move_and_slide()

func play_random_glitch_sound():
	# Stop all currently playing sounds
	for sound in glitch_sounds:
		sound.stop()
	
	# If our available sounds list is empty, refill it
	if available_sound_indices.size() == 0:
		# Create array with indices of all sounds
		for i in range(glitch_sounds.size()):
			available_sound_indices.append(i)
		# Shuffle the indices
		available_sound_indices.shuffle()
	
	# Get the next index from our shuffled list
	var index = available_sound_indices.pop_back()
	# Play the selected sound
	glitch_sounds[index].play()

func start_glitch():
	play_random_glitch_sound()
	is_glitching = true
	glitch_timer = 0.0
	# Saves original position & rotation before glitch.
	original_position = global_position
	original_rotation = $CameraBox/Camera3D.rotation
	emit_signal("player_position", global_position, original_rotation)
	# Configures flash effect.
	flash_timer = flash_duration
	flash_overlay.color.a = flash_opacity
	
	# Teletransport to previous position & a randomized rotation.
	var past_state = position_history[0]
	global_position = past_state.position
	# $CameraBox/Camera3D.rotation = past_state.camera_rotation
	# Option 1: Use rotation_degrees with wider range
	# Option 2: Focus on Y-axis rotation (most disorienting but comfortable)
	$CameraBox/Camera3D.rotation.y = randf_range(-PI, PI) # Full 360° rotation
	$CameraBox/Camera3D.rotation.x = original_rotation.x + randf_range(-1.0, 1.0) # Small tilt
	$CameraBox/Camera3D.rotation.z = randf_range(-0.2, 0.2) # Small roll
	# print_debug("random camera rotation ", random_camera_rotation)
	# $CameraBox/Camera3D.rotation = random_camera_rotation
	film_grain_shader.set_shader_parameter("noise_intensity", 0.2)
	
	# Emit signal that glitch has started
	emit_signal("glitch_started")

func process_glitching(delta):
	glitch_timer += delta
	
	if is_glitching:
		# Creates a smooth ramp-up effect to reach full intensity. 
		effect_intensity = min(effect_intensity + delta * 2, 1.0)
	
	# Managment of lightbulb pitch sound while glitching.
	if lightBulbBuzz and lightBulbBuzz.get_node("SFX_FocoParpadeando"):
		var time = Time.get_ticks_msec() / 1000.0
		current_random_pitch = 1.0 + glitch_noise.get_noise_1d(time * 3.0) * 0.4
		lightBulbBuzz.get_node("SFX_FocoParpadeando").pitch_scale = current_random_pitch

	# Flash effect process
	if flash_timer > 0:
		flash_timer -= delta
		var alpha = (flash_timer / flash_duration) * flash_opacity
		flash_overlay.color.a = alpha
	
	# Return to original position after glitching.
	if glitch_timer >= glitch_duration and !returning_from_glitch:
		returning_from_glitch = true
		flash_timer = flash_duration
		flash_overlay.color.a = flash_opacity
		global_position = original_position
		$CameraBox/Camera3D.rotation = original_rotation
	
	if returning_from_glitch and flash_timer <= 0:
		film_grain_shader.set_shader_parameter("noise_intensity", 0.05)
		is_glitching = false
		returning_from_glitch = false
		flash_overlay.color.a = 0
		
		# Emit signal that glitch has ended
		emit_signal("glitch_ended")

func process_footsteps(delta):
	target_volume = -80.0 if !is_walking else initial_db
	current_volume = lerp(current_volume, target_volume, fade_speed * delta)
	
	if footstep_audio:
		footstep_audio.volume_db = current_volume
		
	if is_walking and !footstep_audio.playing:
		footstep_audio.play()
	elif !is_walking and footstep_audio.playing and current_volume <= -79.0:
		footstep_audio.stop()

func enable_movement():
	movement_enabled = true
	print_debug("Movement enabled!")

func disable_movement():
	movement_enabled = false

func _on_smartphone_collision_decision_mode() -> void:
	disable_movement()

func _on_smartphone_collision_choice_made() -> void:
	enable_movement()

func increase_glitch_chance(delta: float) -> void:
	elapsed_time += delta
	print_debug(glitch_chance)
	if elapsed_time < time_until_max_glitch_increase:
		print_debug("Increasing glitch_chance.")
		glitch_chance = lerp(initial_glitch_chance, max_glitch_chance, elapsed_time / time_until_max_glitch_increase)
	else:
		glitch_chance = max_glitch_chance
		print_debug("max_glitch_chance reached.")
		return

func _on_red_bulb_second_light_broken() -> void:
	glitch_enabled = false
	has_lighbulb_broken_twice = true

func enable_glitching() -> void:
	print_debug("Consciousness glitching enabled!")
	glitch_enabled = true

func _on_door_my_room_my_door_banging(state) -> void:
	await get_tree().create_timer(5.0).timeout
	glitch_enabled = state
	glitch_chance = 0.007
