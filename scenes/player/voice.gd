extends AudioStreamPlayer
## Voice — the florist's inner consciousness.
##
## Two layers of behavior:
##
## 1. PANNING — a sinusoidal L↔R rotation with a noise-driven
##    drifting center, applied through a dedicated "Voice" audio
##    bus + AudioEffectPanner. The bus is created at runtime in
##    _ready() so no project-wide bus layout is needed.
##
## 2. NARRATION — a sequential audio queue per game phase,
##    plus interruptive clips reacting to flower events
##    (collected / missed). Sequential clips follow the naming
##    convention `voz-fase{N}-{idx}.ogg` (where N is 1..7, matching
##    NIGHT..SKY). Reaction clips are picked at random from their
##    folder; reactions interrupt the sequential queue and the
##    queue advances past the interrupted clip when the reaction
##    ends.
##
## All audio plays through `self` (this AudioStreamPlayer), so the
## panning automatically applies to every clip.


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

const BUS_NAME: StringName = &"Voice"

## Maps the phase StringName (as written by PhaseManager into
## GameStates.current_phase) to the integer prefix used in the
## sequential audio filenames (voz-fase{N}-{idx}.ext).
const PHASE_TO_INDEX: Dictionary = {
	&"NIGHT": 1,
	&"DAWN": 2,
	&"MIDDAY": 3,
	&"SUNSET": 4,
	&"TWILIGHT": 5,
	&"EMPTY_NIGHT": 6,
	&"SKY": 7,
}


# ---------------------------------------------------------------
# Exported parameters
# ---------------------------------------------------------------

@export_group("Rotation")
## Speed of the L↔R oscillation in Hz (cycles per second).
@export_range(0.0, 1.0, 0.01) var rotation_speed: float = 0.15
## Amplitude of the rotational pan. 0 = mono, 1 = full L/R.
@export_range(0.0, 1.0, 0.01) var rotation_amplitude: float = 0.55
## Initial phase offset in radians. Useful to avoid centered starts.
@export_range(0.0, 6.2832, 0.01) var phase_offset: float = 0.0

@export_group("Drift")
## Speed of the center drift. Scales the noise sampling time.
@export_range(0.0, 1.0, 0.01) var drift_speed: float = 0.08
## How much the pan center wanders. Added to the rotation pan.
@export_range(0.0, 1.0, 0.01) var drift_amplitude: float = 0.35
## FastNoiseLite frequency. Higher = more erratic drift.
@export_range(0.05, 2.0, 0.01) var drift_noise_frequency: float = 0.5
## Noise seed. -1 = randomized at _ready().
@export var drift_seed: int = -1

@export_group("Smoothing")
## Per-frame lerp weight toward the target pan. 1.0 = no smoothing.
@export_range(0.05, 1.0, 0.01) var pan_lerp_weight: float = 0.5
## If false, the pan freezes when the stream is not playing.
@export var update_when_not_playing: bool = true

@export_group("Narration")
## Folder containing voz-fase{N}-{idx}.{ogg|mp3|wav} sequential clips.
@export_dir var sequential_folder: String = "res://assets/audio/narration/sequential"
## Folder of clips played when a flower is collected (interrupts).
@export_dir var collected_folder: String = "res://assets/audio/narration/flower_collected"
## Folder of clips played when a flower QTE fails (interrupts).
@export_dir var missed_folder: String = "res://assets/audio/narration/flower_missed"
## Seconds of silence between consecutive sequential clips.
@export_range(0.0, 30.0, 0.1) var sequential_gap: float = 3.0
## If true, the current phase's sequential queue starts on _ready().
@export var autostart_sequential: bool = true


# ---------------------------------------------------------------
# Private variables — panning
# ---------------------------------------------------------------

var _time: float = 0.0
var _current_pan: float = 0.0
var _noise: FastNoiseLite
var _panner: AudioEffectPanner


# ---------------------------------------------------------------
# Private variables — narration
# ---------------------------------------------------------------

## Phase index (1..7) → ordered Array[AudioStream] of sequential clips.
var _sequential_streams: Dictionary = {}
var _reaction_collected: Array[AudioStream] = []
var _reaction_missed: Array[AudioStream] = []
var _current_phase_idx: int = 1
var _sequential_pos: int = 0
var _is_action_playing: bool = false
var _in_sequential_mode: bool = false


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	_setup_bus()
	_setup_noise()
	bus = BUS_NAME

	_sequential_streams = _scan_sequential()
	_reaction_collected = _scan_audio_files(collected_folder)
	_reaction_missed = _scan_audio_files(missed_folder)

	GameEventBus.phase_changed.connect(_on_phase_changed)
	GameEventBus.flower_collected.connect(_on_flower_collected)
	GameEventBus.flower_missed.connect(_on_flower_missed)
	finished.connect(_on_finished)

	if autostart_sequential:
		_current_phase_idx = PHASE_TO_INDEX.get(GameStates.current_phase, 1)
		_play_next_sequential()


func _process(delta: float) -> void:
	if not update_when_not_playing and not playing:
		return

	_time += delta

	var target: float = _compute_pan(_time)
	_current_pan = lerpf(_current_pan, target, pan_lerp_weight)
	_panner.pan = _current_pan


# ---------------------------------------------------------------
# Private methods — audio bus and panning
# ---------------------------------------------------------------

func _setup_bus() -> void:
	## Creates the "Voice" bus and attaches an AudioEffectPanner.
	## Idempotent: reuses any existing bus/effect after F5/F6.
	var idx: int = AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		AudioServer.add_bus()
		idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(idx, BUS_NAME)

	var panner_idx: int = -1
	for i in AudioServer.get_bus_effect_count(idx):
		if AudioServer.get_bus_effect(idx, i) is AudioEffectPanner:
			panner_idx = i
			break

	if panner_idx == -1:
		AudioServer.add_bus_effect(idx, AudioEffectPanner.new())
		panner_idx = AudioServer.get_bus_effect_count(idx) - 1

	_panner = AudioServer.get_bus_effect(idx, panner_idx)


func _setup_noise() -> void:
	## Initializes the FastNoiseLite used for the center drift.
	_noise = FastNoiseLite.new()
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = drift_noise_frequency
	_noise.seed = drift_seed if drift_seed >= 0 else randi()


func _compute_pan(t: float) -> float:
	## Combines rotation (sin) and drift (noise) layers, clamped.
	var rotation: float = rotation_amplitude * sin(
			rotation_speed * TAU * t + phase_offset
	)
	var drift: float = drift_amplitude * _noise.get_noise_1d(
			drift_speed * t
	)
	return clampf(rotation + drift, -1.0, 1.0)


# ---------------------------------------------------------------
# Private methods — audio scanning
# ---------------------------------------------------------------

func _scan_sequential() -> Dictionary:
	## Builds {phase_idx: Array[AudioStream]} by scanning the
	## sequential_folder for "voz-fase{N}-{idx}" filenames.
	## Each phase's array is ordered by idx ascending.
	var result: Dictionary = {}
	for i in range(1, 8):
		var empty: Array[AudioStream] = []
		result[i] = empty

	if not DirAccess.dir_exists_absolute(sequential_folder):
		return result

	var dir: DirAccess = DirAccess.open(sequential_folder)
	if dir == null:
		return result

	var collected: Dictionary = {}
	for i in range(1, 8):
		collected[i] = []

	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and _is_audio_file(fname):
			var parsed: Dictionary = _parse_sequential_filename(fname)
			if not parsed.is_empty():
				var phase: int = parsed["phase"]
				if phase >= 1 and phase <= 7:
					var path: String = sequential_folder.path_join(fname)
					var s: AudioStream = load(path) as AudioStream
					if s != null:
						(collected[phase] as Array).append({
							"idx": parsed["idx"],
							"stream": s,
						})
		fname = dir.get_next()
	dir.list_dir_end()

	for phase in collected:
		var entries: Array = collected[phase]
		entries.sort_custom(_compare_by_idx)
		var streams: Array[AudioStream] = []
		for entry in entries:
			streams.append(entry["stream"])
		result[phase] = streams

	return result


func _scan_audio_files(folder: String) -> Array[AudioStream]:
	## Loads every audio file in a folder, sorted by filename.
	var result: Array[AudioStream] = []
	if not DirAccess.dir_exists_absolute(folder):
		return result

	var dir: DirAccess = DirAccess.open(folder)
	if dir == null:
		return result

	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and _is_audio_file(fname):
			var path: String = folder.path_join(fname)
			var s: AudioStream = load(path) as AudioStream
			if s != null:
				result.append(s)
		fname = dir.get_next()
	dir.list_dir_end()

	result.sort_custom(_compare_by_path)
	return result


func _is_audio_file(fname: String) -> bool:
	return fname.ends_with(".ogg") or fname.ends_with(".mp3") or fname.ends_with(".wav")


func _parse_sequential_filename(fname: String) -> Dictionary:
	## Parses "voz-fase{phase}-{idx}.{ext}" → {phase: int, idx: int}.
	## Returns {} on no match.
	var regex: RegEx = RegEx.new()
	regex.compile("^voz-fase(\\d+)-(\\d+)\\.")
	var match_result: RegExMatch = regex.search(fname)
	if match_result == null:
		return {}
	return {
		"phase": int(match_result.get_string(1)),
		"idx": int(match_result.get_string(2)),
	}


func _compare_by_idx(a: Dictionary, b: Dictionary) -> bool:
	return a["idx"] < b["idx"]


func _compare_by_path(a: AudioStream, b: AudioStream) -> bool:
	return a.resource_path < b.resource_path


# ---------------------------------------------------------------
# Private methods — narration playback control
# ---------------------------------------------------------------

func _play_next_sequential() -> void:
	## Plays the clip at _sequential_pos for the current phase, if any.
	## Updates _in_sequential_mode based on whether a clip was queued.
	if _is_action_playing:
		return
	var queue: Array = _sequential_streams.get(_current_phase_idx, []) as Array
	if _sequential_pos >= queue.size():
		_in_sequential_mode = false
		return
	_in_sequential_mode = true
	stream = queue[_sequential_pos]
	play()


func _wait_and_advance_sequential() -> void:
	## Waits sequential_gap seconds, then plays the next sequential
	## clip. Aborts if a phase change, action, or external advance
	## happened during the wait.
	var phase_at_start: int = _current_phase_idx
	var pos_at_start: int = _sequential_pos
	await get_tree().create_timer(sequential_gap).timeout
	if _is_action_playing:
		return
	if _current_phase_idx != phase_at_start:
		return
	if _sequential_pos != pos_at_start:
		return
	_play_next_sequential()


func _play_action_audio(pool: Array[AudioStream]) -> void:
	## Interrupts current playback and plays a random clip from
	## the pool. Sets _is_action_playing so _on_finished can
	## resume the sequential queue afterwards.
	if pool.is_empty():
		return
	_is_action_playing = true
	if playing:
		stop()
	stream = pool[randi() % pool.size()]
	play()


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_phase_changed(new_phase: StringName) -> void:
	var new_idx: int = PHASE_TO_INDEX.get(new_phase, -1)
	if new_idx <= 0:
		return
	_current_phase_idx = new_idx
	_sequential_pos = 0
	_is_action_playing = false
	stop()
	_play_next_sequential()


func _on_flower_collected(_flower_data: Resource) -> void:
	_play_action_audio(_reaction_collected)


func _on_flower_missed(_flower_data: Resource) -> void:
	_play_action_audio(_reaction_missed)


func _on_finished() -> void:
	if _is_action_playing:
		_is_action_playing = false
		if _in_sequential_mode:
			_sequential_pos += 1
			_wait_and_advance_sequential()
		return
	# Natural end of a sequential clip.
	_sequential_pos += 1
	_wait_and_advance_sequential()
