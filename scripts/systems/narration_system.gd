extends Node
## The florist's consciousness — her inner voice.
##
## Manages all voice narration in the game using an Event Queue
## pattern: narrations arrive from many sources but only one
## plays at a time. If a new one arrives while another is
## playing, it waits in line. Priority narrations (like the
## final line) can interrupt whatever is playing.
##
## PHASE-AWARE NARRATION:
## The same event (e.g., "flower_collected") triggers different
## voice lines depending on the current phase. In DAWN, the
## florist speaks serenely. In TWILIGHT, she stutters and
## fragments. This is achieved by organizing audio files in
## folders with phase-prefixed filenames:
##
##   assets/audio/narration/flower_collected/dawn_01.mp3
##   assets/audio/narration/flower_collected/sunset_01.mp3
##
## AMBIENT NARRATION:
## Between events, the florist thinks out loud. Ambient lines
## play on a timer while the player walks. The interval between
## ambient thoughts decreases as deterioration increases (she
## talks to herself more as confusion grows).
##
## SETUP:
## 1. Add an AudioStreamPlayer as a child of this node.
## 2. Assign it in the Inspector via the @export.
## 3. Create the folder structure in assets/audio/narration/.
## 4. Place .mp3 files following the naming convention.


# ---------------------------------------------------------------
# Export variables
# ---------------------------------------------------------------

## The AudioStreamPlayer that actually plays the voice.
@export var narration_player: AudioStreamPlayer


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

## Base path where all narration folders live.
const NARRATION_BASE_PATH: String = "res://assets/audio/narration/"

## Categories of narration. Each maps to a subfolder.
## When a narration_requested signal arrives with one of these
## IDs, we look in the matching subfolder for a phase-specific file.
const CATEGORIES: Array[StringName] = [
	&"phase_enter",
	&"flower_collected",
	&"flower_missed",
	&"involuntary_pause",
	&"ambient",
	&"wrong_key",
	&"priority",
]

## Priority narration IDs that interrupt whatever is playing.
const PRIORITY_IDS: Array[StringName] = [
	&"near_end",
	&"terminal_lucidity",
	&"final_line",
]

## Ambient narration timing per phase.
## interval_min/max: seconds between ambient thoughts.
## If "enabled" is false, no ambient narration for that phase.
const AMBIENT_SETTINGS: Dictionary = {
	&"NIGHT": {
		"enabled": true,
		"interval_min": 15.0,
		"interval_max": 25.0,
	},
	&"DAWN": {
		"enabled": true,
		"interval_min": 20.0,
		"interval_max": 35.0,
	},
	&"MIDDAY": {
		"enabled": true,
		"interval_min": 18.0,
		"interval_max": 30.0,
	},
	&"SUNSET": {
		"enabled": true,
		"interval_min": 15.0,
		"interval_max": 25.0,
	},
	&"TWILIGHT": {
		"enabled": true,
		"interval_min": 10.0,
		"interval_max": 20.0,
	},
	&"EMPTY_NIGHT": {
		"enabled": true,
		"interval_min": 8.0,
		"interval_max": 15.0,
	},
	&"SKY": { "enabled": false },
}


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

## The queue of pending narrations (Event Queue pattern).
## Each entry is a Dictionary: { "category": ..., "phase": ... }
var _queue: Array[Dictionary] = []

## Whether a narration is currently playing.
var _is_playing: bool = false

## The ID of the currently playing narration (for signals).
var _current_narration_id: StringName = &""

## Timer for ambient narration.
var _time_until_next_ambient: float = -1.0

## Whether ambient narration is enabled for the current phase.
var _ambient_enabled: bool = false

## Cached current phase name (lowercase, for file lookup).
var _current_phase_lower: String = "night"

## Cached current phase name (uppercase, for settings lookup).
var _current_phase: StringName = &"NIGHT"

## Cache of discovered audio files per category per phase.
## Format: { "flower_collected": { "dawn": ["path1", "path2"], ... } }
## Built on _ready() by scanning the folders.
var _audio_cache: Dictionary = {}


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	# Build the audio file cache.
	_scan_narration_folders()

	# Connect to EventBus signals.
	GameEventBus.narration_requested.connect(
			_on_narration_requested
	)
	GameEventBus.phase_changed.connect(_on_phase_changed)
	GameEventBus.involuntary_pause_started.connect(
			_on_involuntary_pause_started
	)
	GameEventBus.flower_collected.connect(_on_flower_collected)
	GameEventBus.flower_missed.connect(_on_flower_missed)
	GameEventBus.player_pressed_wrong_key.connect(
			_on_wrong_key_pressed
	)

	# Connect the audio player's finished signal.
	if narration_player:
		narration_player.finished.connect(_on_audio_finished)
	else:
		push_warning("[NARRATION] AudioStreamPlayer not assigned!")

	# Schedule the first ambient thought.
	_update_ambient_settings(&"NIGHT")


func _process(delta: float) -> void:
	# Ambient narration countdown.
	if not _ambient_enabled:
		return
	if _time_until_next_ambient < 0.0:
		return
	if not GameDeteriorationClock.is_running():
		return
	if _is_playing:
		return

	_time_until_next_ambient -= delta

	if _time_until_next_ambient <= 0.0:
		_request_ambient_narration()


# ---------------------------------------------------------------
# Public methods
# ---------------------------------------------------------------

func is_playing() -> bool:
	## Whether a narration is currently playing.
	return _is_playing


# ---------------------------------------------------------------
# Private methods — Core playback
# ---------------------------------------------------------------

func _play_narration(
		category: String, phase_hint: String, narration_id: StringName
) -> void:
	## Finds and plays an audio file for the given category and phase.
	## If multiple files exist for that combination, picks one randomly.
	var path: String = _find_audio_file(category, phase_hint)

	if path.is_empty():
		print("[NARRATION] No audio found: %s/%s" % [category, phase_hint])
		# Even without audio, emit signals so other systems
		# can react (useful for testing without audio files).
		GameEventBus.narration_started.emit(narration_id)
		# Simulate a short duration for testing.
		var timer: SceneTreeTimer = get_tree().create_timer(2.0)
		timer.timeout.connect(
				func() -> void: _on_audio_finished()
		)
		_is_playing = true
		_current_narration_id = narration_id
		return

	var stream: AudioStream = load(path)
	if not stream:
		push_warning("[NARRATION] Could not load: %s" % path)
		return

	_current_narration_id = narration_id
	_is_playing = true
	narration_player.stream = stream
	narration_player.play()
	GameEventBus.narration_started.emit(narration_id)

	print("[NARRATION] Playing: %s (%s)" % [narration_id, path])


func _interrupt_and_play(
		category: String, phase_hint: String, narration_id: StringName
) -> void:
	## Stops whatever is playing and immediately plays this one.
	if _is_playing and narration_player:
		narration_player.stop()
		_is_playing = false
	_queue.clear()
	_play_narration(category, phase_hint, narration_id)


func _enqueue(
		category: String, phase_hint: String, narration_id: StringName
) -> void:
	## Adds a narration to the queue. It will play when the
	## current one finishes.
	_queue.append({
		"category": category,
		"phase_hint": phase_hint,
		"narration_id": narration_id,
	})


func _play_next_in_queue() -> void:
	## Plays the next narration in the queue, if any.
	if _queue.is_empty():
		return

	var next: Dictionary = _queue.pop_front()
	_play_narration(
			next.get("category", ""),
			next.get("phase_hint", ""),
			next.get("narration_id", &""),
	)


# ---------------------------------------------------------------
# Private methods — File discovery
# ---------------------------------------------------------------

func _scan_narration_folders() -> void:
	## Scans all narration subfolders and builds the cache.
	## This runs once at _ready() so we don't hit the filesystem
	## every time a narration is requested.
	_audio_cache.clear()

	for category: StringName in CATEGORIES:
		var folder_path: String = NARRATION_BASE_PATH + category + "/"
		_audio_cache[category] = _scan_folder_for_phases(folder_path)

	print("[NARRATION] Audio cache built: %s" % str(_audio_cache.keys()))


func _scan_folder_for_phases(folder_path: String) -> Dictionary:
	## Scans a folder and groups files by phase prefix.
	## Returns: { "dawn": ["full_path_1.mp3", ...], "night": [...] }
	var result: Dictionary = {}

	if not DirAccess.dir_exists_absolute(folder_path):
		return result

	var dir: DirAccess = DirAccess.open(folder_path)
	if not dir:
		return result

	dir.list_dir_begin()
	var file_name: String = dir.get_next()

	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".mp3"):
			# Extract the phase prefix: "dawn_01.mp3" → "dawn"
			var parts: PackedStringArray = file_name.split("_")
			if parts.size() >= 2:
				var phase_prefix: String = parts[0]
				var full_path: String = folder_path + file_name

				if phase_prefix not in result:
					result[phase_prefix] = []
				result[phase_prefix].append(full_path)

		file_name = dir.get_next()

	dir.list_dir_end()
	return result


func _find_audio_file(category: String, phase_hint: String) -> String:
	## Finds a random audio file for the given category and phase.
	## Returns empty string if nothing found.
	if category not in _audio_cache:
		return ""

	var phase_files: Dictionary = _audio_cache[category]

	if phase_hint in phase_files:
		var files: Array = phase_files[phase_hint]
		if files.size() > 0:
			return files.pick_random()

	return ""


# ---------------------------------------------------------------
# Private methods — Ambient narration
# ---------------------------------------------------------------

func _update_ambient_settings(phase: StringName) -> void:
	## Updates the ambient narration timer for the new phase.
	if phase in AMBIENT_SETTINGS:
		var settings: Dictionary = AMBIENT_SETTINGS[phase]
		_ambient_enabled = settings.get("enabled", false)
		if _ambient_enabled:
			_schedule_next_ambient(settings)
		else:
			_time_until_next_ambient = -1.0
	else:
		_ambient_enabled = false
		_time_until_next_ambient = -1.0


func _schedule_next_ambient(settings: Dictionary) -> void:
	## Sets a random countdown until the next ambient thought.
	_time_until_next_ambient = randf_range(
			settings.get("interval_min", 15.0),
			settings.get("interval_max", 30.0),
	)


func _request_ambient_narration() -> void:
	## Triggers an ambient narration for the current phase.
	if _is_playing:
		# Reschedule — don't interrupt other narrations.
		if _current_phase in AMBIENT_SETTINGS:
			_schedule_next_ambient(AMBIENT_SETTINGS[_current_phase])
		return

	_play_narration("ambient", _current_phase_lower, &"ambient")

	# Schedule the next one.
	if _current_phase in AMBIENT_SETTINGS:
		_schedule_next_ambient(AMBIENT_SETTINGS[_current_phase])


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_narration_requested(narration_id: StringName) -> void:
	## Generic narration request. Used by systems that emit
	## a specific narration ID (like "involuntary_pause").
	## Checks if it's a priority narration first.
	if narration_id in PRIORITY_IDS:
		_interrupt_and_play(
				"priority", narration_id as String, narration_id
		)
	elif not _is_playing:
		_play_narration(
				narration_id as String, _current_phase_lower, narration_id
		)
	else:
		_enqueue(
				narration_id as String, _current_phase_lower, narration_id
		)


func _on_phase_changed(new_phase: StringName) -> void:
	## Update the cached phase and play a phase-enter narration.
	_current_phase = new_phase
	_current_phase_lower = (new_phase as String).to_lower()

	# Update ambient settings.
	_update_ambient_settings(new_phase)

	# Play a phase-enter narration.
	if _is_playing:
		_enqueue("phase_enter", _current_phase_lower, &"phase_enter")
	else:
		_play_narration(
				"phase_enter", _current_phase_lower, &"phase_enter"
		)


func _on_involuntary_pause_started(duration: float) -> void:
	## The player just froze. Play an involuntary pause narration.
	if not _is_playing:
		_play_narration(
				"involuntary_pause",
				_current_phase_lower,
				&"involuntary_pause",
		)
	else:
		_enqueue(
				"involuntary_pause",
				_current_phase_lower,
				&"involuntary_pause",
		)


func _on_flower_collected(flower_data: Resource) -> void:
	## A flower was picked. React with a phase-appropriate line.
	if not _is_playing:
		_play_narration(
				"flower_collected",
				_current_phase_lower,
				&"flower_collected",
		)
	else:
		_enqueue(
				"flower_collected",
				_current_phase_lower,
				&"flower_collected",
		)


func _on_flower_missed(flower_data: Resource) -> void:
	## A QTE was failed. React with dignity.
	if not _is_playing:
		_play_narration(
				"flower_missed",
				_current_phase_lower,
				&"flower_missed",
		)
	else:
		_enqueue(
				"flower_missed",
				_current_phase_lower,
				&"flower_missed",
		)


func _on_wrong_key_pressed(
		expected_action: StringName, pressed_key: String
) -> void:
	## The player pressed a key that used to work. Confusion.
	## Only play if nothing else is playing — this is low priority.
	if not _is_playing:
		_play_narration(
				"wrong_key",
				_current_phase_lower,
				&"wrong_key",
		)


func _on_audio_finished() -> void:
	## The current narration finished. Announce it and check queue.
	var finished_id: StringName = _current_narration_id
	_is_playing = false
	_current_narration_id = &""

	GameEventBus.narration_finished.emit(finished_id)

	# Play next in queue if there is one.
	_play_next_in_queue()
