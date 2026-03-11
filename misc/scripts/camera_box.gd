extends Node3D

# Wait time to give the player freedom of movement at the start
@export var timer_intro: float = 10.0

# Mouse sensitivity for box rotation
@export var mouse_sensitivity: float = 0.005
@export var rotation_smoothness: float = 0.1
@export var inertia_strength: float = 0.85
signal camera_box_direction

# Rotation variables
var target_rotation: float = 0.0
var current_rotation: float = 0.0
var rotation_velocity: float = 0.0
var movement_enabled: bool = false

func _ready():
	# Set mouse mode
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	# Initialize the rotation
	current_rotation = rotation.y
	target_rotation = current_rotation

	# Set timer to enable movement
	var timer = Timer.new()
	timer.wait_time = timer_intro
	timer.one_shot = true
	timer.connect("timeout", enable_movement)
	add_child(timer)
	timer.start()

func _process(delta):
	if movement_enabled:
		process_rotation(delta)

# Handle smooth rotation of the box
func process_rotation(_delta):
	# Smooth interpolation between current and target rotation
	current_rotation = lerp_angle(current_rotation, target_rotation, rotation_smoothness)
	rotation_velocity *= inertia_strength
	
	# Apply rotation only on Y axis (horizontal)
	rotation.y = current_rotation

	# Emit signal with current direction
	emit_signal("camera_box_direction", get_forward_vector())

# Returns the box's current forward direction vector
func get_forward_vector() -> Vector3:
	return -global_transform.basis.z

# Enable or disable movement
func enable_movement():
	movement_enabled = true
	
func disable_movement():
	movement_enabled = false
