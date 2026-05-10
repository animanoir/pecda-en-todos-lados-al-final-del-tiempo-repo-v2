# @tool
class_name GrassField
extends MultiMeshInstance3D
## Generates a field of grass blades using MultiMesh and updates
## the player position uniform for interactive displacement.
##
## Attach this script to a MultiMeshInstance3D node in the garden
## scene. It procedurally scatters grass blade quads across a
## defined area and feeds the player's world position to the
## shader every physics frame.

## How many grass blades to spawn. Start with 5000–10000 and
## adjust based on performance. More blades = denser grass.
@export var blade_count: int = 8000

## The area (in meters) where grass will be scattered.
## A value of 20.0 means blades spawn from -10 to +10 on X and Z.
@export var scatter_area: float = 20.0

## Height range for each blade (randomized per instance).
@export var min_blade_height: float = 0.3
@export var max_blade_height: float = 0.6

## Width of each grass blade (in meters).
@export var blade_width: float = 0.06

## Reference to the player node. Set this in the Inspector or
## via code from the garden script.
@export var player_node: CharacterBody3D

var _material: ShaderMaterial


func _ready() -> void:
	_generate_grass()
	_cache_material()


func _physics_process(_delta: float) -> void:
	_update_player_position()


## Creates the MultiMesh with scattered grass blade instances.
func _generate_grass() -> void:
	# --- Step A: Build a single grass blade mesh (a quad) ---
	# This is a vertical rectangle: two triangles forming a plane.
	# UV.y = 0 at the TOP (tip), UV.y = 1 at the BOTTOM (root).
	# The root is at y = 0 so blades sit on the ground naturally.
	var quad := _create_blade_mesh()

	# --- Step B: Configure the MultiMesh ---
	var grass_multimesh := MultiMesh.new()
	grass_multimesh.transform_format = MultiMesh.TRANSFORM_3D
	grass_multimesh.instance_count = blade_count
	grass_multimesh.mesh = quad

	# --- Step C: Scatter instances randomly across the area ---
	var half_area: float = scatter_area / 2.0

	for i: int in range(blade_count):
		var pos := Vector3(
				randf_range(-half_area, half_area),
				0.0,
				randf_range(-half_area, half_area),
		)
		# Random Y rotation so blades face different directions
		var rot_y: float = randf() * TAU
		# Random height variation
		var height_scale: float = randf_range(
				min_blade_height, max_blade_height
		)

		var xform := Transform3D.IDENTITY
		# Rotate around Y axis
		xform = xform.rotated(Vector3.UP, rot_y)
		# Scale height (Y) and keep width (X) constant
		xform = xform.scaled(
				Vector3(1.0, height_scale / max_blade_height, 1.0)
		)
		# Set position
		xform.origin = pos

		grass_multimesh.set_instance_transform(i, xform)

	multimesh = grass_multimesh


## Builds the quad mesh for a single grass blade.
## Returns an ArrayMesh with proper UVs for the shader.
func _create_blade_mesh() -> ArrayMesh:
	var half_w: float = blade_width / 2.0
	var h: float = max_blade_height

	# Four vertices: bottom-left, bottom-right, top-left, top-right
	# The blade grows from y=0 (root on the ground) to y=h (tip).
	var vertices := PackedVector3Array([
		Vector3(-half_w, 0.0, 0.0),   # 0: bottom-left  (root)
		Vector3(half_w, 0.0, 0.0),    # 1: bottom-right (root)
		Vector3(-half_w, h, 0.0),     # 2: top-left     (tip)
		Vector3(half_w, h, 0.0),      # 3: top-right    (tip)
	])

	# UVs: y=1 at root (bottom), y=0 at tip (top)
	# This matches the shader's expectation:
	#   (1.0 - UV.y) = 0 at root → no sway
	#   (1.0 - UV.y) = 1 at tip  → maximum sway
	var uvs := PackedVector2Array([
		Vector2(0.0, 1.0),  # 0: bottom-left
		Vector2(1.0, 1.0),  # 1: bottom-right
		Vector2(0.0, 0.0),  # 2: top-left
		Vector2(1.0, 0.0),  # 3: top-right
	])

	# Two triangles forming the quad
	var indices := PackedInt32Array([
		0, 1, 2,  # first triangle
		1, 3, 2,  # second triangle
	])

	# Normals pointing up (the shader overrides them anyway)
	var normals := PackedVector3Array([
		Vector3.UP,
		Vector3.UP,
		Vector3.UP,
		Vector3.UP,
	])

	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

	return mesh


## Caches the ShaderMaterial reference for efficient access.
func _cache_material() -> void:
	if multimesh and multimesh.mesh:
		var mat: Material = material_override
		if mat is ShaderMaterial:
			_material = mat as ShaderMaterial


## Sends the player's world position to the shader every frame.
## The shader uses this for the displacement effect where grass
## bends away from the player's feet.
func _update_player_position() -> void:
	if not player_node or not _material:
		return

	_material.set_shader_parameter(
			"player_position", player_node.global_position
	)
