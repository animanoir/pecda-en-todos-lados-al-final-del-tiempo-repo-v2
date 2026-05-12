extends Node3D

@export var float_amplitude:float = 0.1
@export var float_speed:float = 1.5

var _base_y:float
var _time:float = 0.0

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_base_y = position.y


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_time += delta
	position.y = _base_y + sin(_time * float_speed) * float_amplitude
	
