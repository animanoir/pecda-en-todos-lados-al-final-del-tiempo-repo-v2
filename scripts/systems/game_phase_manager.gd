extends Node
## State machine for the game's narrative/ambient phases.
##
## The game flows through phases like chapters in a book,
## but unlike a book, the pages degrade as you turn them.
## Each phase represents a time of day AND a stage of
## cognitive decline, intertwined:
##
##   NIGHT → DAWN → MIDDAY → SUNSET → TWILIGHT → EMPTY_NIGHT → SKY
##
## This node listens to threshold crossings from the
## DeteriorationClock and manages the transitions.
## It does NOT control shaders, narration, or controls —
## it just announces "we are now in phase X" and lets
## each system react on its own.


# ---------------------------------------------------------------
# Enums
# ---------------------------------------------------------------

## All possible phases, in order of progression.
## Each phase corresponds to a time of day and a level
## of cognitive deterioration.
enum Phase {
	## The serene garden at night. Tutorial. First flower visible.
	## Deterioration clock is NOT running yet.
	NIGHT,

	## Dawn breaks after the first flower. Warm light reveals
	## personal details. First involuntary pause may occur.
	DAWN,

	## Harsh midday light. Objects from the past appear.
	## First control remap. Videos of wilting bouquet begin.
	MIDDAY,

	## Golden sunset. The florist speaks to someone absent.
	## Controls remap again. Repeated phrases start appearing.
	SUNSET,

	## The border between day and night. Objects from the shop
	## appear. The body remembers what the mind forgets.
	TWILIGHT,

	## Night again, but empty. Almost no objects. Fragmented
	## narration. Movement feels like effort, stopping feels natural.
	EMPTY_NIGHT,

	## Everything disappears. Only sky and the last flower.
	## Terminal lucidity. The final QTE is one single key.
	SKY,
}

## Maps threshold names (from DeteriorationClock) to phases.
## When the clock emits "PHASE_DAWN", we transition to Phase.DAWN.
const THRESHOLD_TO_PHASE: Dictionary = {
	&"PHASE_DAWN": Phase.DAWN,
	&"PHASE_MIDDAY": Phase.MIDDAY,
	&"PHASE_SUNSET": Phase.SUNSET,
	&"PHASE_TWILIGHT": Phase.TWILIGHT,
	&"PHASE_EMPTY_NIGHT": Phase.EMPTY_NIGHT,
	&"PHASE_SKY": Phase.SKY,
}


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

## The current phase. Starts at NIGHT.
var _current_phase: Phase = Phase.NIGHT


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	# Listen for threshold crossings from the clock.
	GameEventBus.deterioration_threshold_reached.connect(
			_on_threshold_reached
	)

	# Listen for the first flower to start the clock.
	GameEventBus.flower_collected.connect(_on_flower_collected)

	# Listen for game ending to handle the final transition.
	GameEventBus.game_ending.connect(_on_game_ending)


# ---------------------------------------------------------------
# Public methods
# ---------------------------------------------------------------

func get_current_phase() -> Phase:
	## Returns the current phase enum value.
	return _current_phase


func get_phase_name() -> StringName:
	## Returns the current phase as a readable StringName.
	## Useful for the narration system and debugging.
	return StringName(Phase.keys()[_current_phase])


# ---------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------

func _transition_to(new_phase: Phase) -> void:
	## Handles the transition from the current phase to a new one.
	## Updates internal state, records in GameState, and announces
	## the change through the EventBus.
	var old_phase: Phase = _current_phase
	_current_phase = new_phase

	# Convert enum to StringName for other systems to read.
	var phase_name: StringName = StringName(Phase.keys()[new_phase])

	# Record in the notebook.
	GameStates.current_phase = phase_name
	GameStates.phases_visited.append(phase_name)

	# Announce to the world.
	GameEventBus.phase_changed.emit(phase_name)

	# Debug feedback — remove or reduce later.
	var old_name: String = Phase.keys()[old_phase]
	var new_name: String = Phase.keys()[new_phase]
	print("[PHASE] %s → %s" % [old_name, new_name])


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_threshold_reached(threshold_name: StringName) -> void:
	## A threshold was crossed. Check if it maps to a phase.
	if threshold_name in THRESHOLD_TO_PHASE:
		var new_phase: Phase = THRESHOLD_TO_PHASE[threshold_name]
		_transition_to(new_phase)


func _on_flower_collected(flower_data: Resource) -> void:
	## When the first flower is collected, two things happen:
	## 1. The deterioration clock starts (the game truly begins).
	## 2. We transition from NIGHT to DAWN.
	##
	## For subsequent flowers, this does nothing — the clock
	## is already running and phases are driven by thresholds.
	if GameStates.get_flower_count() == 1:
		GameDeteriorationClock.start()
		_transition_to(Phase.DAWN)


func _on_game_ending() -> void:
	## The clock hit 1.0. If we're not already in SKY phase,
	## force the transition. This is a safety net.
	if _current_phase != Phase.SKY:
		_transition_to(Phase.SKY)
