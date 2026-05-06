@tool
class_name MagicDotSwarm
extends Node3D
## Spawns a cluster of MagicDot instances within a spherical volume.
##
## Drop this node where you want a flock of glowing dots to appear,
## assign a packed MagicDot scene, and tune count and bounds. Place
## one swarm per hedge cluster, near zone corners, or above water.

@export var dot_scene: PackedScene
@export_range(1, 30) var dot_count: int = 8
@export var bounds_radius: float = 3.0
@export var spawn_height_range: Vector2 = Vector2(0.3, 1.8)


func _ready() -> void:
	_spawn_dots()


func _spawn_dots() -> void:
	if dot_scene == null:
		push_warning("MagicDotSwarm has no dot_scene assigned.")
		return
	
	for i in dot_count:
		var dot := dot_scene.instantiate() as MagicDot
		if dot == null:
			push_warning("dot_scene must be a MagicDot scene.")
			return
		add_child(dot)
		dot.position = _random_spawn_offset()
		dot.bounds_radius = bounds_radius


func _random_spawn_offset() -> Vector3:
	var angle := randf() * TAU
	var radius := randf_range(0.0, bounds_radius * 0.8)
	return Vector3(
		cos(angle) * radius,
		randf_range(spawn_height_range.x, spawn_height_range.y),
		sin(angle) * radius,
	)
