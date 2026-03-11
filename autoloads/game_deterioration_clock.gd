extends Node
## The master clock of cognitive decline.
##
## A single float from 0.0 (lucid) to 1.0 (complete dissolution)
## that drives EVERYTHING in the game. Every system reads this
## value to know how degraded things should be.
##
## Think of it as a thermometer — it doesn't decide anything,
## but everyone reacts to its temperature.
##
## IMPORTANT: The clock does NOT start automatically.
## It begins when the player collects their first flower.
## It pauses during events (QTEs, involuntary stops, videos)
## and resumes when the player regains control.


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

## Total duration in seconds of active exploration.
## Only ticks when the player is free to move.
const GAME_DURATION: float = 100.0 # 900.0 seconds = 15 minutes

## Phase thresholds — "alarms" that fire when crossed.
## Each entry maps a deterioration value to a phase name.
## The PhaseManager (or any system) listens for these
## and reacts accordingly.
const THRESHOLDS: Dictionary = {
	0.12: &"PHASE_DAWN",
	0.30: &"PHASE_MIDDAY",
	0.50: &"PHASE_SUNSET",
	0.70: &"PHASE_TWILIGHT",
	0.85: &"PHASE_EMPTY_NIGHT",
	0.92: &"PHASE_SKY",
}


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

## The raw elapsed time in seconds. This is the "real" counter.
var _elapsed_time: float = 0.0

## Stores the deterioration value from the previous frame.
var _previous_value: float = 0.0

## Which thresholds have already been crossed.
## We track this so each alarm only fires ONCE.
var _crossed_thresholds: Array[float] = []

## Whether the clock is actively ticking.
## Starts as false — waits for the first flower.
var _is_running: bool = false


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	GameEventBus.qte_started.connect(_on_qte_started)
	GameEventBus.qte_completed.connect(_on_qte_completed)

func _process(delta: float) -> void:
	if not _is_running:
		return

	_elapsed_time += delta

	var current_value: float = get_value()

	GameEventBus.deterioration_updated.emit(current_value)

	_check_thresholds(current_value)

	_previous_value = current_value

	if current_value >= 1.0:
		_is_running = false
		GameEventBus.game_ending.emit()


# ---------------------------------------------------------------
# Public methods
# ---------------------------------------------------------------

func start() -> void:
	## Starts the clock. Called when the first flower is collected.
	_is_running = true
	_elapsed_time = 0.0
	_previous_value = 0.0
	_crossed_thresholds.clear()


func pause() -> void:
	## Freezes the clock. Time stops advancing.
	_is_running = false


func resume() -> void:
	## Unfreezes the clock. Time resumes advancing.
	_is_running = true


func get_value() -> float:
	## Returns the current deterioration as a 0.0–1.0 float.
	if GAME_DURATION <= 0.0:
		return 1.0
	return clampf(_elapsed_time / GAME_DURATION, 0.0, 1.0)


func is_running() -> bool:
	## Returns whether the clock is currently ticking.
	return _is_running


func reset() -> void:
	## Resets everything to the initial state.
	_elapsed_time = 0.0
	_previous_value = 0.0
	_crossed_thresholds.clear()
	_is_running = false


# ---------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------

func _check_thresholds(current_value: float) -> void:
	## Checks if any threshold was crossed since last frame.
	for threshold: float in THRESHOLDS:
		if threshold in _crossed_thresholds:
			continue

		if _previous_value < threshold and current_value >= threshold:
			_crossed_thresholds.append(threshold)
			var threshold_name: StringName = THRESHOLDS[threshold]
			GameEventBus.deterioration_threshold_reached.emit(
					threshold_name
			)

func _on_qte_started(_flower: Node3D) -> void:
	pause()


func _on_qte_completed(_success: bool) -> void:
	resume()
