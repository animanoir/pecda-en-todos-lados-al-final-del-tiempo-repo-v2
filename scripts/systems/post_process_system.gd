extends CanvasLayer
## Drives the post-processing shader: desaturation + ghost bursts.
##
## TWO EFFECTS:
## 1. DESATURATION — Continuous. Increases with deterioration.
##    At 0.0 = full color. At 1.0 = nearly grayscale.
##    Uses a curved function so color drains slowly at first
##    and aggressively near the end.
##
## 2. GHOST (double vision) — In bursts. A random timer triggers
##    ghost episodes that fade in and out. As deterioration
##    increases, bursts happen more often, last longer, and
##    are more intense.
##
## SETUP:
## 1. Create a CanvasLayer in your scene.
## 2. Add a ColorRect child that covers the full screen.
## 3. Assign the post_process.gdshader to the ColorRect's material.
## 4. Put this script on the CanvasLayer.
## 5. Assign the ColorRect in the Inspector.
##
## The CanvasLayer should have its layer set to a high number
## (e.g., 100) so it renders on top of everything.


# ---------------------------------------------------------------
# Export variables
# ---------------------------------------------------------------

## The full-screen ColorRect with the shader material.
@export var shader_rect: ColorRect


# ---------------------------------------------------------------
# Constants — Ghost burst settings
# ---------------------------------------------------------------

## Ghost burst settings per deterioration range.
## As deterioration increases, bursts become more frequent,
## longer, and more intense.
##
## interval_min/max: seconds between bursts.
## duration_min/max: how long each burst lasts.
## intensity_min/max: the ghost uniform value during burst.
## spread_min/max: how far the double vision spreads.
const GHOST_TIERS: Array[Dictionary] = [
	{
		"threshold": 0.20,
		"enabled": false,
	},
	{
		"threshold": 0.40,
		"enabled": true,
		"interval_min": 20.0,
		"interval_max": 35.0,
		"duration_min": 1.5,
		"duration_max": 3.0,
		"intensity_min": 0.3,
		"intensity_max": 0.5,
		"spread": 0.08,
	},
	{
		"threshold": 0.60,
		"enabled": true,
		"interval_min": 12.0,
		"interval_max": 22.0,
		"duration_min": 2.5,
		"duration_max": 5.0,
		"intensity_min": 0.5,
		"intensity_max": 0.7,
		"spread": 0.12,
	},
	{
		"threshold": 0.80,
		"enabled": true,
		"interval_min": 6.0,
		"interval_max": 14.0,
		"duration_min": 3.0,
		"duration_max": 7.0,
		"intensity_min": 0.6,
		"intensity_max": 0.85,
		"spread": 0.15,
	},
	{
		"threshold": 1.01,
		"enabled": true,
		"interval_min": 2.0,
		"interval_max": 5.0,
		"duration_min": 5.0,
		"duration_max": 10.0,
		"intensity_min": 0.8,
		"intensity_max": 1.0,
		"spread": 0.2,
	},
]


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

## Reference to the shader material.
var _shader_material: ShaderMaterial = null

## Current deterioration value (cached from signal).
var _current_deterioration: float = 0.0

## Ghost burst state.
var _ghost_active: bool = false
var _time_until_next_ghost: float = -1.0
var _ghost_remaining: float = 0.0
var _ghost_target_intensity: float = 0.0
var _ghost_current_intensity: float = 0.0
var _ghost_target_spread: float = 0.0

## Current tier index (which GHOST_TIERS entry we're using).
var _current_tier: Dictionary = {}


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	# Set this CanvasLayer to render on top.
	layer = 100

	# Get the shader material from the ColorRect.
	if shader_rect and shader_rect.material is ShaderMaterial:
		_shader_material = shader_rect.material as ShaderMaterial
	else:
		push_warning("[PostProcess] ColorRect or ShaderMaterial not found!")

	# Listen for deterioration updates.
	GameEventBus.deterioration_updated.connect(
			_on_deterioration_updated
	)

	# Initialize ghost system.
	_update_ghost_tier(0.0)


func _process(delta: float) -> void:
	return
	if not _shader_material:
		return

	# -- Update desaturation --
	_update_desaturation()

	# -- Update ghost bursts --
	if _ghost_active:
		_process_ghost_burst(delta)
	else:
		_process_ghost_countdown(delta)

	# Smoothly interpolate the ghost intensity (fade in/out).
	_ghost_current_intensity = lerpf(
			_ghost_current_intensity,
			_ghost_target_intensity,
			delta * 4.0
	)
	_shader_material.set_shader_parameter(
			"ghost", _ghost_current_intensity
	)


# ---------------------------------------------------------------
# Private methods — Desaturation
# ---------------------------------------------------------------

func _update_desaturation() -> void:
	## Maps deterioration to desaturation using a curve.
	## The curve is gentle at first and steep at the end:
	##   deterioration 0.0 → desaturation 0.0
	##   deterioration 0.3 → desaturation ~0.05
	##   deterioration 0.6 → desaturation ~0.25
	##   deterioration 0.8 → desaturation ~0.55
	##   deterioration 1.0 → desaturation 0.85
	## We cap at 0.85 instead of 1.0 so it's never fully
	## grayscale — a trace of color always remains (dignity).
	var desat: float = _current_deterioration * _current_deterioration * 0.85
	_shader_material.set_shader_parameter("desaturation", desat)


# ---------------------------------------------------------------
# Private methods — Ghost bursts
# ---------------------------------------------------------------

func _process_ghost_countdown(delta: float) -> void:
	## Counts down to the next ghost burst.
	if _time_until_next_ghost < 0.0:
		return

	if not GameDeteriorationClock.is_running():
		return

	_time_until_next_ghost -= delta

	if _time_until_next_ghost <= 0.0:
		_start_ghost_burst()


func _process_ghost_burst(delta: float) -> void:
	## Manages the duration of an active ghost burst.
	_ghost_remaining -= delta

	if _ghost_remaining <= 0.0:
		_end_ghost_burst()


func _start_ghost_burst() -> void:
	## Activates a ghost burst with random intensity.
	_ghost_active = true

	var duration: float = randf_range(
			_current_tier.get("duration_min", 2.0),
			_current_tier.get("duration_max", 4.0),
	)
	_ghost_remaining = duration

	_ghost_target_intensity = randf_range(
			_current_tier.get("intensity_min", 0.3),
			_current_tier.get("intensity_max", 0.5),
	)

	_ghost_target_spread = _current_tier.get("spread", 0.06)
	_shader_material.set_shader_parameter(
			"ghost_spread", _ghost_target_spread
	)

	print("[POSTFX] Ghost burst: %.1fs at %.0f%%" % [
		duration, _ghost_target_intensity * 100.0,
	])


func _end_ghost_burst() -> void:
	## Fades out the ghost effect and schedules the next one.
	_ghost_active = false
	_ghost_target_intensity = 0.0
	_schedule_next_ghost()


func _schedule_next_ghost() -> void:
	## Sets a random countdown until the next ghost burst.
	if not _current_tier.get("enabled", false):
		_time_until_next_ghost = -1.0
		return

	_time_until_next_ghost = randf_range(
			_current_tier.get("interval_min", 20.0),
			_current_tier.get("interval_max", 40.0),
	)


func _update_ghost_tier(deterioration: float) -> void:
	## Finds the correct tier for the current deterioration level.
	for tier: Dictionary in GHOST_TIERS:
		if deterioration < tier.get("threshold", 1.0):
			# Only reschedule if the tier actually changed.
			if tier != _current_tier:
				_current_tier = tier
				if not _ghost_active:
					_schedule_next_ghost()
			return


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_deterioration_updated(value: float) -> void:
	_current_deterioration = value
	_update_ghost_tier(value)
