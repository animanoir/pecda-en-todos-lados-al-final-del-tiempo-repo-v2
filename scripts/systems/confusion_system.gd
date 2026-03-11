extends Node
## Orchestrates the progressive degradation of the game's rules.
##
## This is the heart of the "poetic gameplay" — it takes what
## the player has learned (controls, object positions, visual
## clarity) and systematically unmakes it.
##
## THREE RESPONSIBILITIES:
## 1. Involuntary pauses — the player stops without warning.
## 2. Control remapping — WASD gets scrambled.
## 3. Speed reduction — the player walks slower over time.
##
## HOW INVOLUNTARY PAUSES WORK:
## A hidden timer counts down while the player walks.
## When it hits zero, the player freezes for a few seconds.
## The timer resets with a new random interval.
## As deterioration increases, pauses happen more often
## and last longer. During a pause, the deterioration
## clock freezes too — time only passes while you move.


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

## Control remap presets, from mild to severe.
## Each preset is a complete key-to-action mapping.
## KEY_I always maps to tutorial — it's the anchor.
const REMAP_PRESETS: Array[Dictionary] = [
	# Preset 0: Swap forward/back (disorienting but learnable)
	{
		KEY_W: &"move_back",
		KEY_S: &"move_forward",
		KEY_A: &"move_left",
		KEY_D: &"move_right",
		KEY_E: &"interact",
		KEY_I: &"tutorial",
	},
	# Preset 1: Rotate movement clockwise (confusing)
	{
		KEY_W: &"move_right",
		KEY_S: &"move_left",
		KEY_A: &"move_forward",
		KEY_D: &"move_back",
		KEY_E: &"interact",
		KEY_I: &"tutorial",
	},
	# Preset 2: Full scramble (devastating)
	{
		KEY_W: &"move_left",
		KEY_S: &"move_right",
		KEY_A: &"move_back",
		KEY_D: &"move_forward",
		KEY_E: &"interact",
		KEY_I: &"tutorial",
	},
]

## Involuntary pause settings per phase.
## Each entry defines: can pauses happen, how often (min/max
## seconds between pauses), and how long they last (min/max).
## These are ranges — the actual values are picked randomly.
const PAUSE_SETTINGS: Dictionary = {
	&"NIGHT": { "enabled": false },
	&"DAWN": {
		"enabled": true,
		"interval_min": 25.0,
		"interval_max": 40.0,
		"duration_min": 2.0,
		"duration_max": 4.0,
	},
	&"MIDDAY": {
		"enabled": true,
		"interval_min": 18.0,
		"interval_max": 30.0,
		"duration_min": 3.0,
		"duration_max": 6.0,
	},
	&"SUNSET": {
		"enabled": true,
		"interval_min": 12.0,
		"interval_max": 22.0,
		"duration_min": 4.0,
		"duration_max": 8.0,
	},
	&"TWILIGHT": {
		"enabled": true,
		"interval_min": 8.0,
		"interval_max": 15.0,
		"duration_min": 5.0,
		"duration_max": 10.0,
	},
	&"EMPTY_NIGHT": {
		"enabled": true,
		"interval_min": 5.0,
		"interval_max": 10.0,
		"duration_min": 6.0,
		"duration_max": 12.0,
	},
	&"SKY": { "enabled": false },
}

## Which phases trigger a control remap, and which preset to use.
const PHASE_TO_REMAP: Dictionary = {
	&"MIDDAY": 0,
	&"SUNSET": 1,
	&"TWILIGHT": 2,
}


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

## Countdown until the next involuntary pause.
## When this reaches zero, the player freezes.
var _time_until_next_pause: float = -1.0

## How long the current pause lasts (countdown).
var _pause_remaining: float = 0.0

## Whether an involuntary pause is currently happening.
var _is_paused: bool = false

## Whether the pause system is active at all.
## Disabled during NIGHT and SKY phases.
var _pauses_enabled: bool = false

## The current phase's pause settings (cached).
var _current_pause_settings: Dictionary = {}


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	# Listen for phase changes to update pause settings and remaps.
	GameEventBus.phase_changed.connect(_on_phase_changed)

	# Listen for deterioration to adjust player speed.
	GameEventBus.deterioration_updated.connect(
			_on_deterioration_updated
	)


func _process(delta: float) -> void:
	if _is_paused:
		_process_pause(delta)
		return

	if _pauses_enabled and _time_until_next_pause > 0.0:
		_process_pause_countdown(delta)


# ---------------------------------------------------------------
# Private methods — Pause system
# ---------------------------------------------------------------

func _process_pause_countdown(delta: float) -> void:
	## Counts down to the next involuntary pause.
	## Only ticks while the clock is running (player is moving).
	if not GameDeteriorationClock.is_running():
		return

	_time_until_next_pause -= delta

	if _time_until_next_pause <= 0.0:
		_start_involuntary_pause()


func _process_pause(delta: float) -> void:
	## Manages the duration of an active pause.
	_pause_remaining -= delta

	if _pause_remaining <= 0.0:
		_end_involuntary_pause()


func _start_involuntary_pause() -> void:
	## Freezes the player and pauses the clock.
	_is_paused = true

	# Pick a random duration from the current phase's settings.
	var duration: float = randf_range(
			_current_pause_settings.get("duration_min", 3.0),
			_current_pause_settings.get("duration_max", 5.0),
	)
	_pause_remaining = duration

	# Freeze the player.
	GameStates.can_player_move = false

	# Pause the deterioration clock — time stops during confusion.
	GameDeteriorationClock.pause()

	# Announce it so narration and UI can react.
	GameEventBus.involuntary_pause_started.emit(duration)
	GameEventBus.narration_requested.emit(&"involuntary_pause")

	print("[CONFUSION] Involuntary pause: %.1fs" % duration)


func _end_involuntary_pause() -> void:
	## Unfreezes the player and resumes the clock.
	_is_paused = false

	# Unfreeze the player.
	GameStates.can_player_move = true

	# Resume the deterioration clock.
	GameDeteriorationClock.resume()

	# Schedule the next pause.
	_schedule_next_pause()

	# Announce it.
	GameEventBus.involuntary_pause_ended.emit()

	print("[CONFUSION] Pause ended. Next in %.1fs" % _time_until_next_pause)


func _schedule_next_pause() -> void:
	## Sets a random countdown until the next involuntary pause.
	if not _pauses_enabled or _current_pause_settings.is_empty():
		_time_until_next_pause = -1.0
		return

	_time_until_next_pause = randf_range(
			_current_pause_settings.get("interval_min", 20.0),
			_current_pause_settings.get("interval_max", 40.0),
	)


# ---------------------------------------------------------------
# Private methods — Control remapping
# ---------------------------------------------------------------

func _remap_controls(preset_index: int) -> void:
	## Sends a new control mapping through the EventBus.
	## The InputManager picks it up and updates its translation
	## table. The TutorialPanel also picks it up and updates
	## the displayed keys.
	if preset_index < 0 or preset_index >= REMAP_PRESETS.size():
		return

	var new_map: Dictionary = REMAP_PRESETS[preset_index]
	GameEventBus.controls_remapped.emit(new_map)

	print("[CONFUSION] Controls remapped to preset %d" % preset_index)


# ---------------------------------------------------------------
# Private methods — Speed reduction
# ---------------------------------------------------------------

func _on_deterioration_updated(value: float) -> void:
	## Slows the player down as deterioration increases.
	## Uses a squared curve so the slowdown is gentle at first
	## and aggressive near the end.
	##
	## At 0.0: multiplier = 1.0 (full speed)
	## At 0.5: multiplier = 0.75 (barely noticeable)
	## At 0.8: multiplier = 0.36 (noticeably slow)
	## At 1.0: multiplier = 0.05 (nearly frozen)
	GameStates.player_speed_multiplier = lerpf(
			1.0, 0.05, value * value
	)


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_phase_changed(new_phase: StringName) -> void:
	## Reacts to phase transitions.
	## Updates pause settings and triggers control remaps.

	# Update pause settings for this phase.
	if new_phase in PAUSE_SETTINGS:
		_current_pause_settings = PAUSE_SETTINGS[new_phase]
		_pauses_enabled = _current_pause_settings.get("enabled", false)
	else:
		_pauses_enabled = false
		_current_pause_settings = {}

	# Schedule the first pause for this phase (if enabled).
	if _pauses_enabled:
		_schedule_next_pause()
	else:
		_time_until_next_pause = -1.0

	# Trigger control remap if this phase has one.
	if new_phase in PHASE_TO_REMAP:
		var preset_index: int = PHASE_TO_REMAP[new_phase]
		_remap_controls(preset_index)
