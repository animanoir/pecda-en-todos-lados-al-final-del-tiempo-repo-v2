extends Camera3D

# Wait time to give the player freedom of movement at the start
@export var timer_intro: float = 10.0

# Parameters for the drunk movement of camera
@export var drunk_intensity: float = 0.5
@export var drunk_speed: float = 2.0
@export var rotation_limit: float = 0.1
@export var position_noise: float = 0.2
@export var mouse_sensitivity: float = 0.005
@export var max_vertical_angle: float = 80.0

# Parameters for the initial fade-in
@export var initial_fade_duration: float = 2.0
var fade_overlay: ColorRect
var fade_timer: float = 0.0
var is_fading: bool = true

# Parameters for motion smoothing
@export var rotation_smoothness: float = 0.1
@export var inertia_strength: float = 0.85

var noise = FastNoiseLite.new()
var time: float = 0.0

# Variables to maintain the initial and current transformations
var initial_position: Vector3
var initial_rotation: Vector3
var rotation_input: Vector2 = Vector2.ZERO
var target_rotation: Vector2 = Vector2.ZERO
var rotation_velocity: Vector2 = Vector2.ZERO
var target_position: Vector3
var current_position: Vector3

# State control
var movement_enabled = false

func _ready():
	setup_fade_overlay()

	# Initialize rotations
	initial_rotation = rotation
	target_rotation = Vector2(deg_to_rad(219.7), deg_to_rad(57.8))
	rotation_input = target_rotation

	# Initialize positions
	initial_position = position
	target_position = initial_position
	current_position = initial_position

	# Set up the noise generator
	noise.seed = randi()
	noise.frequency = 0.5

	# Set timer to enable movement
	var timer = Timer.new()
	timer.wait_time = timer_intro
	timer.one_shot = true
	timer.connect("timeout", enable_movement)
	add_child(timer)
	timer.start()

func _input(event):
	if !movement_enabled:
		return
		
	# Process mouse movement
	if event is InputEventMouseMotion:
		var mouse_motion = Vector2(-event.relative.x, -event.relative.y) * mouse_sensitivity
		rotation_velocity = rotation_velocity.lerp(mouse_motion, 1.0 - inertia_strength)
		target_rotation += rotation_velocity

	# Limit vertical rotation
	target_rotation.y = clamp(target_rotation.y,
	deg_to_rad(-max_vertical_angle),
	deg_to_rad(max_vertical_angle))

func _process(delta):
	time += delta
	process_drunk_effect(delta)
	
	if !movement_enabled:
		process_fade(delta)
		return
	else:
		process_movement(delta)
		process_drunk_effect(delta)

# Set up the overlay for the fade effect
func setup_fade_overlay():
	fade_overlay = ColorRect.new()
	fade_overlay.color = Color(0, 0, 0, 1.0)
	fade_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	
	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 128
	canvas_layer.add_child(fade_overlay)
	add_child(canvas_layer)

# Process the initial fade effect
func process_fade(delta):
	if is_fading:
		fade_timer += delta
		var alpha = max(0, 1.0 - (fade_timer / initial_fade_duration))
		fade_overlay.color.a = alpha

		if fade_timer >= initial_fade_duration:
			is_fading = false
			fade_overlay.queue_free()
			
func enable_movement():
	movement_enabled = true
	
func disable_movement():
	movement_enabled = false

# Process the normal camera movement
func process_movement(_delta):
	if movement_enabled:
		rotation_input = rotation_input.lerp(target_rotation, rotation_smoothness)
		rotation_velocity *= inertia_strength

		transform.basis = Basis()
		rotate_y(rotation_input.x)
		rotate_object_local(Vector3.RIGHT, rotation_input.y)

# Process the drunk effect of the camera
func process_drunk_effect(_delta):
	# Generate noise values for each axis
	var noise_x = noise.get_noise_2d(time * drunk_speed, 0.0) * drunk_intensity * 0.5
	var noise_y = noise.get_noise_2d(0.0, time * drunk_speed) * drunk_intensity * 0.5
	var noise_z = noise.get_noise_2d(time * drunk_speed, time * drunk_speed) * drunk_intensity * 0.5

	transform.basis = Basis()

	# Maintain initial rotation or apply mouse rotation based on state

	rotate_y(rotation_input.x)
	rotate_object_local(Vector3.RIGHT, rotation_input.y)

	# Apply the wobble effect
	rotate_object_local(Vector3.RIGHT, noise_x * rotation_limit)
	rotate_object_local(Vector3.UP, noise_y * rotation_limit)
	rotate_object_local(Vector3.FORWARD, noise_z * rotation_limit)

	# Calculate and apply position offset
	target_position = initial_position + Vector3(
		noise_x * position_noise,
		noise_y * position_noise,
		noise_z * position_noise
	)

	current_position = current_position.lerp(target_position, rotation_smoothness)
	position = current_position

func _on_smartphone_collision_decision_mode() -> void:
	disable_movement()

func _on_smartphone_collision_choice_made() -> void:
	enable_movement()

# Returns the camera's current forward direction vector
func get_forward_vector() -> Vector3:
	return -global_transform.basis.z

# Returns the camera's current position
func get_camera_center() -> Vector3:
	return global_position
	
# Optional: Function to attach a 3D model that will follow the camera direction
func attach_to_forward_view(model: Node3D, distance: float = 2.0, offset: Vector3 = Vector3.ZERO) -> void:
	if model:
		# Position the model in front of the camera
		var forward = get_forward_vector()
		var center = get_camera_center()
		model.global_position = center + (forward * distance) + offset
		
		# Make the model face the camera
		model.look_at(center, Vector3.UP)
		model.rotate_y(PI) # Rotate 180 degrees so it faces the camera directly
