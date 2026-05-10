@tool
extends MultiMeshInstance3D

@export var bush_count: int = 200 : set = _set_bush_count
@export var corridor_length: float = 50.0 : set = _set_corridor_length
@export var corridor_width: float = 2.0 : set = _set_corridor_width
@export var randomness: float = 0.3 : set = _set_randomness
@export var random_seed: int = 0 : set = _set_random_seed
@export var regenerate: bool = false : set = _trigger_regenerate


func _set_bush_count(value: int) -> void:
	bush_count = value
	_populate()


func _set_corridor_length(value: float) -> void:
	corridor_length = value
	_populate()


func _set_corridor_width(value: float) -> void:
	corridor_width = value
	_populate()


func _set_randomness(value: float) -> void:
	randomness = value
	_populate()


func _set_random_seed(value: int) -> void:
	random_seed = value
	_populate()


func _trigger_regenerate(_value: bool) -> void:
	_populate()


func _ready() -> void:
	if multimesh and multimesh.instance_count == 0:
		_populate()


func _populate() -> void:
	if not multimesh:
		return
	if not multimesh.mesh:
		push_warning("BushCorridor: no mesh assigned to MultiMesh")
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = random_seed

	multimesh.instance_count = bush_count

	for i in bush_count:
		var t := Transform3D()
		var z := float(i) / float(bush_count) * corridor_length
		var x_offset := rng.randf_range(-randomness, randomness)
		var side := 1.0 if i % 2 == 0 else -1.0
		t.origin = Vector3(side * corridor_width + x_offset, 0.0, z)
		t = t.rotated_local(Vector3.UP, rng.randf_range(0.0, TAU))
		var scale_var := rng.randf_range(0.85, 1.15)
		t = t.scaled_local(Vector3.ONE * scale_var)
		multimesh.set_instance_transform(i, t)
