class_name PlayerController
extends CharacterBody3D
## Basic first-person controller with WASD movement and mouse look.

@export var move_speed: float = 4.0
@export var mouse_sensitivity: float = 0.002

@onready var _camera_head: Node3D = $CameraHead
@onready var _camera: Camera3D = $CameraHead/Camera3D


func _ready() -> void:
	# Capture the mouse so it doesn't leave the window
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	# --- MOUSE LOOK ---
	if event is InputEventMouseMotion:
		var mouse_event := event as InputEventMouseMotion

		# Horizontal rotation: rotate the CameraHead (the "neck")
		_camera_head.rotate_y(-mouse_event.relative.x * mouse_sensitivity)

		# Vertical rotation: rotate only the Camera (the "eyes")
		_camera.rotate_x(-mouse_event.relative.y * mouse_sensitivity)

		# Clamp vertical look so you can't look behind yourself
		_camera.rotation.x = clampf(
				_camera.rotation.x, -PI / 2.0, PI / 2.0
		)

	# Let the player free the mouse with Escape
	if event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(_delta: float) -> void:
	# --- WASD MOVEMENT ---
	# Get the raw input as a 2D vector (-1 to 1 on each axis)
	var input_dir := Input.get_vector(
			"ui_left", "ui_right", "ui_forward", "ui_back"
	)

	# Convert 2D input into 3D world direction based on where we're looking
	var forward: Vector3 = -_camera_head.global_basis.z
	var right: Vector3 = _camera_head.global_basis.x

	# Zero out Y so we don't fly up/down when looking up
	forward.y = 0.0
	right.y = 0.0
	forward = forward.normalized()
	right = right.normalized()

	# Combine into final direction
	var direction := (right * input_dir.x + forward * input_dir.y).normalized()

	# Apply movement
	velocity = direction * move_speed
	move_and_slide()
