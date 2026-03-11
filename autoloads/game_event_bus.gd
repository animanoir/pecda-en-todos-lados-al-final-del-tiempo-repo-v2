extends Node
## Global signal bus for decoupled communication between systems.
##
## Think of this as a bulletin board in an office: anyone can
## post a notice, and anyone can read it, but nobody needs to
## know each other personally. This is the Observer pattern.
##
## HOW TO USE:
## - To announce something happened:
##       GameEventBus.some_signal.emit(arguments)
##
## - To listen for something:
##       GameEventBus.some_signal.connect(_on_some_signal)
##
## RULES:
## 1. Only declare signals here. No logic, no variables.
## 2. Group signals by category with comments.
## 3. Every signal should have a doc comment explaining
##    WHAT happened (not what should happen in response).
## 4. Signal names use past tense: "thing_happened", not "do_thing".


# ---------------------------------------------------------------
# Game flow
# ---------------------------------------------------------------

## The game has started. The opening cinematic can begin.
signal game_started

## The deterioration clock reached 1.0. Time to end.
signal game_ending

## Everything is done. Bouquet screen has been shown.
signal game_ended


# ---------------------------------------------------------------
# Deterioration
# ---------------------------------------------------------------

## Emitted every frame while the clock is running.
## [param value] is the current deterioration (0.0 to 1.0).
## Use this for smooth interpolations: shader parameters,
## player speed, fog density, color desaturation, etc.
signal deterioration_updated(value: float)

## Emitted ONCE when the clock crosses a threshold.
## [param threshold_name] identifies which threshold was crossed.
## Example: &"PHASE_DAWN", &"PHASE_MIDDAY", etc.
## Use this for discrete, one-time changes: phase transitions,
## control remaps, narration triggers.
signal deterioration_threshold_reached(threshold_name: StringName)


# ---------------------------------------------------------------
# Phase flow
# ---------------------------------------------------------------

## The game transitioned to a new narrative/ambient phase.
## [param new_phase] is the phase name (e.g., &"NIGHT", &"DAWN").
## Systems that need to react to phase changes listen here.
signal phase_changed(new_phase: StringName)


# ---------------------------------------------------------------
# Player actions
# ---------------------------------------------------------------

## The player interacted with something (pressed the interact key).
## [param target] is the Node3D the player is looking at / near.
signal player_interacted(target: Node3D)

## The player pressed a key that USED to do something before
## a control remap, but no longer does. This means the player
## is confused — they remember the old controls.
## [param expected_action] what the key used to do.
## [param pressed_key] the label of the key they pressed.
signal player_pressed_wrong_key(
		expected_action: StringName,
		pressed_key: String,
)


# ---------------------------------------------------------------
# Confusion / Involuntary events
# ---------------------------------------------------------------

## The player was forcibly stopped (involuntary pause).
## Movement is frozen. The clock is paused.
## [param duration] how long the pause will last in seconds.
signal involuntary_pause_started(duration: float)

## The involuntary pause just ended. Movement and clock resume.
signal involuntary_pause_ended


# ---------------------------------------------------------------
# Controls / Confusion
# ---------------------------------------------------------------

## The ConfusionSystem changed the control mapping.
## [param new_map] is the new key-to-action dictionary.
## Format: { KEY_W: &"move_left", KEY_S: &"move_forward", ... }
signal controls_remapped(new_map: Dictionary)

## The control labels changed (for the tutorial panel).
## [param new_content] is { action_name: key_label } dictionary.
## Format: { &"move_forward": "S", &"move_back": "W", ... }
signal tutorial_content_changed(new_content: Dictionary)


# ---------------------------------------------------------------
# Flower system
# ---------------------------------------------------------------

## A flower was successfully collected (QTE passed).
## [param flower_data] is the Resource with the flower's info.
signal flower_collected(flower_data: Resource)

## A flower was missed (QTE failed).
## [param flower_data] is the Resource of the flower that was missed.
signal flower_missed(flower_data: Resource)

## A QTE sequence just started.
## [param flower] is the flower Node3D that triggered it.
signal qte_started(flower: Node3D)

## A QTE sequence just ended.
## [param success] is true if the player completed it.
signal qte_completed(success: bool)


# ---------------------------------------------------------------
# Narration
# ---------------------------------------------------------------

## A system is requesting a narration line to be played.
## [param narration_id] identifies which line to play.
## The NarrationSystem decides if it should play, queue, or skip.
signal narration_requested(narration_id: StringName)

## A narration line just started playing.
## [param narration_id] identifies which line is playing.
signal narration_started(narration_id: StringName)

## A narration line just finished playing.
## [param narration_id] identifies which line just ended.
signal narration_finished(narration_id: StringName)
