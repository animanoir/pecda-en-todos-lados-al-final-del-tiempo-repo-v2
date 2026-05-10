extends MeshInstance3D

var noise: FastNoiseLite = FastNoiseLite.new()

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	noise.frequency = 0.6
	noise.seed = randi()

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	var t:float = Time.get_ticks_msec() / 1000.0
	rotation.x = noise.get_noise_1d(t) * 0.06
