class_name FlowerPickup
extends StaticBody3D
## A simple interactable flower placeholder.
##
## Add this to a StaticBody3D with a CollisionShape3D (box) and a
## MeshInstance3D (box mesh) to create a flower the player can find.
## Must be in the "interactables" group to be detected by the raycast.
##
## On successful collection, plays a random success sound effect
## and shrinks away. The sound survives the node being freed
## by reparenting to the scene root before queue_free.

@export var flower_name: String = "Rosa"

var _is_collected: bool = false

## Preloaded success sounds. Loaded once, shared across instances.
## If you add more files, just add them to this array.
static var _success_sounds: Array[AudioStream] = []
static var _sounds_loaded: bool = false


func _ready() -> void:
	add_to_group("interactables")

	# Load success sounds once (shared across all FlowerPickup instances).
	if not _sounds_loaded:
		_load_success_sounds()
		_sounds_loaded = true


func interact() -> void:
	if _is_collected:
		return

	_is_collected = true
	print("Collected flower: ", flower_name)

	# Play a random success sound.
	_play_random_success_sound()

	# Simple visual feedback: shrink and disappear.
	var tween: Tween = create_tween()
	tween.tween_property(self, "scale", Vector3.ZERO, 0.3)
	tween.tween_callback(queue_free)


func _play_random_success_sound() -> void:
	## Creates a temporary AudioStreamPlayer, plays a random
	## success sound, and auto-frees when done.
	##
	## Why not put an AudioStreamPlayer on the FlowerPickup?
	## Because the node gets queue_free'd in 0.3 seconds,
	## but the sound is 2 seconds long. The sound would get
	## cut short. Instead, we create a temporary player on
	## the scene root — it outlives this node.
	if _success_sounds.is_empty():
		return

	var stream: AudioStream = _success_sounds.pick_random()

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "SFX" # Optional: route to an SFX audio bus.

	# Add to scene root so it survives this node being freed.
	get_tree().root.add_child(player)
	player.play()

	# Auto-free when the sound finishes.
	player.finished.connect(player.queue_free)


static func _load_success_sounds() -> void:
	## Scans the success sounds folder and loads all .mp3 files.
	var folder_path: String = "res://assets/audio/sfx/flower_success/"

	if not DirAccess.dir_exists_absolute(folder_path):
		push_warning("[FlowerPickup] SFX folder not found: %s" % folder_path)
		return

	var dir: DirAccess = DirAccess.open(folder_path)
	if not dir:
		return

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".mp3"):
			var full_path: String = folder_path + file_name
			var stream: AudioStream = load(full_path)
			if stream:
				_success_sounds.append(stream)
		file_name = dir.get_next()

	dir.list_dir_end()

	print("[FlowerPickup] Loaded %d success sounds." % _success_sounds.size())
