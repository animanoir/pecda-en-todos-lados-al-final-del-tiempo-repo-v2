extends Node
## The game's notebook — records WHAT happened without deciding
## what to DO about it.
##
## Stores persistent session data: collected flowers, current
## phase, player state. Any system can read this data, but only
## the system responsible for each piece of data should write it.
##
## Example: Only the FlowerSystem calls add_flower().
## Only the PhaseManager updates current_phase.
## But anyone can READ get_flower_count() or current_phase.


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

## Maximum number of flowers that exist in the world.
const MAX_FLOWERS: int = 15


# ---------------------------------------------------------------
# Collected flowers
# ---------------------------------------------------------------

## The flowers the player has successfully collected this session.
## Each entry is a Resource (FlowerData) with the flower's info:
## its name, illustration texture, narration ID, etc.
var collected_flowers: Array[Resource] = []


# ---------------------------------------------------------------
# Phase tracking
# ---------------------------------------------------------------

## The current narrative/ambient phase.
## Updated by the PhaseManager when a transition occurs.
## Other systems can read this to know "where" we are.
var current_phase: StringName = &"NIGHT"

## History of all phases visited, in order.
## Useful for debugging and for the narration system to know
## what the player has already experienced.
var phases_visited: Array[StringName] = []


# ---------------------------------------------------------------
# Player state
# ---------------------------------------------------------------

## Multiplier applied to the player's movement speed.
## 1.0 = normal speed. Decreases as deterioration increases.
## The PlayerController reads this every frame.
var player_speed_multiplier: float = 1.0

## Whether the player is currently allowed to move.
## Set to false during: QTEs, involuntary stops, videos,
## opening cinematic, final sequence.
var can_player_move: bool = true

## Whether a QTE (flower-collection minigame) is currently running.
## Written by the InteractionManager when a QTE starts/ends.
## UI panels that listen for keys also bound to QTE letters
## (e.g., the tutorial/inventory panel on I) read this to
## suppress their toggles while the player is solving the QTE.
var is_qte_active: bool = false


# ---------------------------------------------------------------
# Public methods
# ---------------------------------------------------------------

func add_flower(flower_data: Resource) -> void:
	## Records a collected flower and announces it to the world.
	## Called by the FlowerSystem when a QTE is completed.
	collected_flowers.append(flower_data)
	GameEventBus.flower_collected.emit(flower_data)


func get_flower_count() -> int:
	## How many flowers the player has collected so far.
	return collected_flowers.size()


func has_collected_any_flower() -> bool:
	## Has the player collected at least one flower?
	## Used by the DeteriorationClock to know if it should start.
	return collected_flowers.size() > 0


func reset() -> void:
	## Wipes everything clean. Used when restarting the game.
	collected_flowers.clear()
	current_phase = &"NIGHT"
	phases_visited.clear()
	player_speed_multiplier = 1.0
	can_player_move = false
	is_qte_active = false
