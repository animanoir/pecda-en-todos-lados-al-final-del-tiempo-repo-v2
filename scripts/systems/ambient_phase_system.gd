extends Node
## Manages the visual atmosphere across phases.
##
## Think of this as a theater lighting board. When the phase
## changes, this script smoothly transitions all the visual
## properties: sky brightness, fog color, fog density,
## ambient light, and the directional light (sun/moon).
##
## It does NOT decide when phases change — the PhaseManager
## does that. This script just listens for "phase_changed"
## and tweens the visuals accordingly.
##
## SETUP:
## 1. Place this script on a Node in your scene.
## 2. Assign the WorldEnvironment and DirectionalLight3D
##    in the Inspector via the @export variables.
## 3. That's it — it connects to the EventBus automatically.


# ---------------------------------------------------------------
# Export variables — assign these in the Inspector
# ---------------------------------------------------------------

## The WorldEnvironment node in your scene.
@export var world_environment: WorldEnvironment

## The main directional light (sun/moon).
@export var directional_light: DirectionalLight3D

## How long the visual transition takes (in seconds).
@export var transition_duration: float = 8.0


# ---------------------------------------------------------------
# Constants — Visual presets for each phase
# ---------------------------------------------------------------

## Each preset defines target values for Environment and Light.
## When a phase starts, we tween FROM current values TO these.
##
## Properties:
##   bg_energy      -> Environment.background_energy_multiplier
##   ambient_color  -> Environment.ambient_light_color
##   ambient_energy -> Environment.ambient_light_energy
##   fog_color      -> Environment.fog_light_color
##   fog_density    -> Environment.fog_density
##   vol_fog_density -> Environment.volumetric_fog_density
##   light_color    -> DirectionalLight3D.light_color
##   light_energy   -> DirectionalLight3D.light_energy
##   light_rotation -> DirectionalLight3D.rotation_degrees.x
##                     (sun angle — negative = from above)
const PHASE_PRESETS: Dictionary = {
	# NIGHT — The serene garden. Dark, moonlit, peaceful.
	&"NIGHT": {
		"bg_energy": 0.07,
		"ambient_color": Color(0.05, 0.05, 0.15),
		"ambient_energy": 0.3,
		"fog_color": Color(0.04, 0.04, 0.1),
		"fog_density": 0.02,
		"vol_fog_density": 0.0,
		"light_color": Color(0.6, 0.7, 0.9),
		"light_energy": 0.15,
		"light_rotation": -30.0,
	},

	# DAWN — Warm light creeps in. Hope and disorientation.
	&"DAWN": {
		"bg_energy": 0.25,
		"ambient_color": Color(0.3, 0.2, 0.15),
		"ambient_energy": 0.6,
		"fog_color": Color(0.25, 0.15, 0.1),
		"fog_density": 0.015,
		"vol_fog_density": 0.005,
		"light_color": Color(1.0, 0.7, 0.4),
		"light_energy": 0.5,
		"light_rotation": -15.0,
	},

	# MIDDAY — Harsh, overexposed. Memories burn bright.
	&"MIDDAY": {
		"bg_energy": 0.6,
		"ambient_color": Color(0.5, 0.45, 0.4),
		"ambient_energy": 1.0,
		"fog_color": Color(0.5, 0.45, 0.35),
		"fog_density": 0.008,
		"vol_fog_density": 0.003,
		"light_color": Color(1.0, 0.95, 0.85),
		"light_energy": 1.2,
		"light_rotation": -60.0,
	},

	# SUNSET — Golden, melancholic. The absent person.
	&"SUNSET": {
		"bg_energy": 0.35,
		"ambient_color": Color(0.4, 0.25, 0.15),
		"ambient_energy": 0.7,
		"fog_color": Color(0.35, 0.2, 0.1),
		"fog_density": 0.025,
		"vol_fog_density": 0.01,
		"light_color": Color(1.0, 0.5, 0.2),
		"light_energy": 0.7,
		"light_rotation": -10.0,
	},

	# TWILIGHT — Unnatural colors. The border dissolves.
	&"TWILIGHT": {
		"bg_energy": 0.15,
		"ambient_color": Color(0.2, 0.15, 0.25),
		"ambient_energy": 0.4,
		"fog_color": Color(0.15, 0.1, 0.2),
		"fog_density": 0.04,
		"vol_fog_density": 0.02,
		"light_color": Color(0.6, 0.4, 0.7),
		"light_energy": 0.3,
		"light_rotation": -5.0,
	},

	# EMPTY_NIGHT — Void. Almost nothing visible.
	&"EMPTY_NIGHT": {
		"bg_energy": 0.03,
		"ambient_color": Color(0.03, 0.03, 0.06),
		"ambient_energy": 0.15,
		"fog_color": Color(0.02, 0.02, 0.05),
		"fog_density": 0.06,
		"vol_fog_density": 0.04,
		"light_color": Color(0.3, 0.3, 0.5),
		"light_energy": 0.05,
		"light_rotation": -25.0,
	},
	# SKY — Ethereal, pristine blue. Floating among clouds. Peace.
	&"SKY": {
		"bg_energy": 1.8,
		"ambient_color": Color(0.65, 0.78, 0.95),
		"ambient_energy": 1.8,
		"fog_color": Color(0.7, 0.82, 0.98),
		"fog_density": 0.0,
		"vol_fog_density": 0.0,
		"light_color": Color(0.8, 0.88, 1.0),
		"light_energy": 0.8,
		"light_rotation": -45.0,
	},
}


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

## The active tween. We keep a reference so we can kill it
## if a new phase starts before the previous transition ends.
var _active_tween: Tween = null


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	GameEventBus.phase_changed.connect(_on_phase_changed)

	if not world_environment:
		push_warning(
				"[AmbientPhaseSystem] WorldEnvironment not assigned!"
		)
	if not directional_light:
		push_warning(
				"[AmbientPhaseSystem] DirectionalLight3D not assigned!"
		)


# ---------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------

func _transition_to_preset(preset: Dictionary, duration: float) -> void:
	## Smoothly tweens all visual properties to the target preset.
	## If a previous transition is still running, it gets killed
	## and the new one starts from wherever the values are now.

	if not world_environment or not world_environment.environment:
		return

	var env: Environment = world_environment.environment

	# Kill any running tween to avoid conflicts.
	if _active_tween and _active_tween.is_running():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.set_parallel(true)
	_active_tween.set_ease(Tween.EASE_IN_OUT)
	_active_tween.set_trans(Tween.TRANS_CUBIC)

	# -- Environment properties --

	_active_tween.tween_property(
			env, "background_energy_multiplier",
			preset.get("bg_energy", 0.07), duration
	)
	_active_tween.tween_property(
			env, "ambient_light_color",
			preset.get("ambient_color", Color.WHITE), duration
	)
	_active_tween.tween_property(
			env, "ambient_light_energy",
			preset.get("ambient_energy", 0.5), duration
	)
	_active_tween.tween_property(
			env, "fog_light_color",
			preset.get("fog_color", Color.WHITE), duration
	)
	_active_tween.tween_property(
			env, "fog_density",
			preset.get("fog_density", 0.01), duration
	)
	_active_tween.tween_property(
			env, "volumetric_fog_density",
			preset.get("vol_fog_density", 0.0), duration
	)

	# -- DirectionalLight3D properties --

	if directional_light:
		_active_tween.tween_property(
				directional_light, "light_color",
				preset.get("light_color", Color.WHITE), duration
		)
		_active_tween.tween_property(
				directional_light, "light_energy",
				preset.get("light_energy", 0.5), duration
		)

		var target_rotation := directional_light.rotation_degrees
		target_rotation.x = preset.get("light_rotation", -30.0)
		_active_tween.tween_property(
				directional_light, "rotation_degrees",
				target_rotation, duration
		)

	print("[AMBIENT] Transitioning... (%.1fs)" % duration)


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_phase_changed(new_phase: StringName) -> void:
	## A phase transition occurred. Look up the preset and tween.
	if new_phase not in PHASE_PRESETS:
		push_warning(
				"[AmbientPhaseSystem] No preset for phase: %s" % new_phase
		)
		return

	var preset: Dictionary = PHASE_PRESETS[new_phase]

	# The first transition (NIGHT -> DAWN) is slower and cinematic.
	# The last one (-> SKY) is the slowest — a long dissolve.
	var duration: float = transition_duration
	if new_phase == &"DAWN":
		duration = transition_duration * 1.5
	elif new_phase == &"SKY":
		duration = transition_duration * 2.0

	_transition_to_preset(preset, duration)

	print("[AMBIENT] Phase -> %s" % new_phase)
