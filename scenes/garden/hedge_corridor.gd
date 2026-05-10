@tool
class_name HedgeCorridor
extends MultiMeshInstance3D
## Procedural hedge corridor built from a single repeating segment.
##
## Stamps N copies of a base mesh end-to-end along the local -Z axis.
## Use a saved external MultiMesh resource at hedge_multimesh.res
## to prevent the transform array from being serialized into the scene.

const MULTIMESH_PATH: String = "res://ASSETS/RESOURCES/hedge_multimesh.res"

@export var base_mesh: Mesh
@export var segment_count: int = 12
@export var segment_length: float = 4.0
@export var lateral_jitter: float = 0.05
@export var rotation_jitter_degrees: float = 4.0
@export var scale_jitter: float = 0.03
@export var random_seed: int = 42
@export var rebuild: bool = false : set = _set_rebuild

var _has_built: bool = false


func _ready() -> void:
	if _has_built:
		return
	_has_built = true
	_load_or_generate()


func _set_rebuild(value: bool) -> void:
	if not value:
		return
	rebuild = false
	_generate()


func _load_or_generate() -> void:
	var existing := load(MULTIMESH_PATH) as MultiMesh
	if existing != null:
		multimesh = existing
		return
	_generate()


func _generate() -> void:
	if base_mesh == null:
		push_warning("HedgeCorridor: base_mesh is not assigned.")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = base_mesh
	mm.instance_count = segment_count

	for i in segment_count:
		var t := Transform3D.IDENTITY

		# Slight randomized rotation around Y to break repetition.
		var yaw := deg_to_rad(rng.randf_range(
			-rotation_jitter_degrees,
			rotation_jitter_degrees,
		))
		t.basis = Basis(Vector3.UP, yaw)

		# Slight non-uniform scale so segments feel less cloned.
		var s := 1.0 + rng.randf_range(-scale_jitter, scale_jitter)
		t.basis = t.basis.scaled(Vector3(s, s, s))

		# Tile along -Z. Add small lateral X jitter to avoid a perfect line.
		var x_offset := rng.randf_range(-lateral_jitter, lateral_jitter)
		t.origin = Vector3(x_offset, 0.0, -segment_length * float(i))

		mm.set_instance_transform(i, t)

	multimesh = mm
	ResourceSaver.save(mm, MULTIMESH_PATH, ResourceSaver.FLAG_COMPRESS)
