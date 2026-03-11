# CLAUDE.md — "En todos lados al final del tiempo"

> Experimental 3D video game exploring cognitive deterioration, dementia, and Alzheimer's.
> Built with **Godot Engine 4.6** using **GDScript**. Academic project funded by PECDA scholarship.

---

## Project Overview

A 15–20 minute first-person narrative experience where the player embodies a dying florist
creating her final bouquet. The game progressively degrades its own controls, visuals, and
rules to simulate cognitive decline — the player loses abilities instead of gaining them.

The final output is a personalized bouquet image (PNG) composed of the watercolor flowers
the player chose to collect, accompanied by a reflective phrase. This image is the game's
"gift" to the player — a tangible memory of an experience about losing memories.

### Design Pillars

1. **Impermanence and deterioration of the present** — the "now" is already dissolving.
2. **The body remembers what the mind forgets** — procedural memory persists.
3. **Attention as a form of love** — noticing beauty even as it fades.
4. **Loss of control tells the story** — mechanical friction IS the narrative.

### Core Design Principles

- "Sentir antes que entender" (Feel before understanding).
- "Perder es recordar" (Losing is remembering).
- "La dignidad permanece" (Dignity remains).
- Inverse progression: the player LOSES abilities over time, never gains them.
- No separation between "playing" and "experiencing the story" — mechanics ARE narrative.

---

## Language Rules

**CRITICAL: All GDScript code MUST be written in English.** Variable names, function names,
comments, class names, documentation — everything in English. Never mix Spanish with
programming constructs. The game's content (narration, UI text shown to the player) is in
Spanish, but code is always English.

---

## GDScript Style Guide (Godot 4.6)

### Naming Conventions

| Element        | Convention     | Example                          |
|----------------|----------------|----------------------------------|
| File names     | snake_case     | `flower_system.gd`               |
| Class names    | PascalCase     | `class_name FlowerSystem`        |
| Node names     | PascalCase     | `BouquetGenerator`, `Player`     |
| Functions      | snake_case     | `func collect_flower():`         |
| Variables      | snake_case     | `var petal_count`                |
| Signals        | snake_case (past tense) | `signal flower_collected` |
| Constants      | CONSTANT_CASE  | `const MAX_FLOWERS = 15`         |
| Enum names     | PascalCase     | `enum FlowerType`                |
| Enum members   | CONSTANT_CASE  | `ROSE, LILY, DAHLIA`            |

- File names MUST match `class_name` converted to snake_case.
- Private members prefixed with `_`: `var _internal_counter`, `func _recalculate()`.
- Signal handlers prefixed with `_on_`: `signal flower_collected` → `func _on_flower_collected()`.
- Never use camelCase for functions or variables.

### Code Order (Every Script)

```
01. @tool / @icon / @static_unload
02. class_name
03. extends
04. ## Documentation comment

05. Signals
06. Enums
07. Constants
08. Static variables
09. @export variables
10. Regular variables (public, then private)
11. @onready variables

12. _static_init()
13. Static methods
14. Virtual callbacks in order:
    _init() → _enter_tree() → _ready() →
    _process() → _physics_process() → other virtuals
15. Public methods
16. Private methods (prefixed with _)
17. Signal callbacks (prefixed with _on_)
18. Inner classes
```

### Static Typing (Mandatory)

Always use static typing. Use `:=` when type is obvious, explicit type when ambiguous:

```gdscript
var direction := Vector3.UP           # Obvious from right side
var health: int = 0                    # Explicit for clarity
var enemies: Array[Enemy] = []         # Typed array
@onready var health_bar: ProgressBar = $UI/HealthBar  # Always explicit for @onready
```

Function signatures MUST have typed parameters and return types:

```gdscript
func take_damage(amount: int, source: Node3D) -> void:
func get_flower_name() -> String:
```

### Formatting Rules

- **Tabs** for indentation (Godot default).
- Lines under **100 characters** (aim for 80).
- **Two blank lines** between functions.
- **One blank line** inside functions to separate logical sections.
- Trailing commas in multiline collections, NOT in single-line.
- Boolean operators: `and`, `or`, `not` — NEVER `&&`, `||`, `!`.
- No unnecessary parentheses in conditions.
- Double quotes by default. Single quotes only to avoid escaping.
- Never omit leading/trailing zeros: `0.5` not `.5`, `2.0` not `2.`.
- Use underscores for large numbers: `1_000_000`.

### Documentation

- `## ` (double hash + space) for doc comments on public API.
- `# ` (hash + space) for regular comments.
- `#` (no space) for disabled code.
- Doc comments on all public functions and exported variables.

---

## Architecture

### Three Architectural Principles

1. **Time governs everything.** A global clock (`DeteriorationClock`) goes from `0.0` to `1.0`.
   When it reaches `1.0`, the game ends. This single value feeds ALL systems.

2. **Systems communicate via signals, not direct references.** Observer pattern through a
   global EventBus. Systems are decoupled — the ConfusionSystem doesn't know the
   PlayerController exists.

3. **State machine for macro flow, signals for micro flow.** Game phases (Night →
   Dawn → Midday → Sunset → Twilight → Empty Night → Sky) are states. Moment-to-moment
   events (collect flower, fail QTE, press wrong key) are signals on the EventBus.

### Autoloads (Global Singletons)

Registered in `project.godot` in this specific order (dependency matters):

| Order | Autoload Name          | File                                  | Purpose                                  |
|-------|------------------------|---------------------------------------|------------------------------------------|
| 1     | `GameEventBus`         | `autoloads/game_event_bus.gd`         | Global signal bus (Observer pattern)     |
| 2     | `GameStates`           | `autoloads/game_states.gd`            | Persistent session data (the "notebook") |
| 3     | `GameDeteriorationClock` | `autoloads/game_deterioration_clock.gd` | Master clock of cognitive decline      |

None of the autoload scripts declare a `class_name` — they use `extends Node` only.

**IMPORTANT:** In code, reference autoloads by their registered PascalCase names:
`GameEventBus`, `GameStates`, `GameDeteriorationClock`.

### Design Patterns Used

| Pattern            | Where                | Why                                                        | Status      |
|--------------------|----------------------|------------------------------------------------------------|-------------|
| Observer           | GameEventBus         | Decouples all system communication                         | Implemented |
| Command            | InputManager         | Separates physical keys from game actions (enables remapping) | Implemented |
| Service Locator    | Autoloads            | Global access to EventBus, GameStates, DeteriorationClock  | Implemented |
| State Machine      | PhaseManager         | Clean phase transitions with clear rules                   | Implemented |
| Event Queue        | NarrationSystem      | Queues narrations, only one plays at a time                | Implemented |
| Flyweight          | FlowerData           | Shared data per flower type (texture, name, narration)     | Planned     |
| Phase Presets      | AmbientPhaseSystem   | Per-phase visual atmosphere with tweened transitions        | Implemented |
| Tier Escalation    | PostProcessSystem    | Deterioration-tier ghost bursts with increasing severity    | Implemented |

---

## Project File Structure

```
res://
├── project.godot
├── autoloads/
│   ├── game_event_bus.gd            # Global signals (Observer pattern)
│   ├── game_states.gd              # Persistent session data
│   └── game_deterioration_clock.gd # Deterioration 0.0 → 1.0
│
├── scenes/
│   ├── player/
│   │   ├── player.tscn              # Root player scene (main scene is garden.tscn)
│   │   ├── player.gd               # Active player script (CharacterBody3D, uses InputManager)
│   │   ├── player_controller.gd    # Legacy bare-bones controller (NOT actively used)
│   │   ├── input_manager.gd        # Command pattern — key-to-action translation
│   │   └── interaction_manager.gd  # Raycast interaction + QTE triggering
│   │
│   ├── garden/
│   │   ├── garden.tscn              # Main scene (project root scene)
│   │   ├── garden.gd               # Garden scene script
│   │   ├── garden_world.gd         # Garden world logic
│   │   ├── flower.gd               # Flower node script
│   │   ├── grassfield.gd           # GrassField — MultiMesh procedural grass (@tool)
│   │   └── objects/                 # (empty — placeholder for dissolving objects)
│   │
│   ├── flowers/
│   │   ├── flower_pickup.tscn       # FlowerPickup scene (StaticBody3D)
│   │   └── flower_pickup.gd        # Interactable flower with collect + disappear
│   │
│   └── ui/
│       ├── tutorial_panel.gd       # Legacy tutorial panel (superseded by tutorial_display)
│       ├── bouqet_screen.gd        # Final bouquet image display (typo in filename)
│       ├── tutorial_display/        # Current tutorial panel implementation
│       │   ├── tutorial_display.tscn # TutorialDisplay scene (CanvasLayer)
│       │   └── tutorial_display.gd  # Listens to controls_remapped, toggles with I key
│       └── qtedisplay/
│           ├── qte_display.tscn     # QTE display scene
│           └── qte_display.gd      # QTE sequence with dissolving opacity
│
├── scripts/
│   └── systems/
│       ├── game_phase_manager.gd    # State machine for game phases (implemented)
│       ├── confusion_system.gd      # Pauses + control remapping + speed reduction (implemented)
│       ├── ambient_phase_system.gd  # Visual atmosphere per phase (implemented)
│       ├── post_process_system.gd   # Desaturation + ghost bursts (implemented)
│       ├── narration_system.gd      # Audio narration queue (implemented)
│       └── flower_system.gd         # QTE logic + collection (stub)
│
├── resources/
│   └── grass_multimesh.tres         # MultiMesh resource for grass
│
├── shaders/
│   ├── grass/
│   │   └── grass_v1.gdshader        # Procedural grass with wind + player displacement
│   ├── fog/
│   │   └── fog_garden.gdshader      # Volumetric fog with noise + density controls
│   └── fx/
│       └── double_vision.gdshader   # Desaturation + ghost/double vision post-process
│
├── assets/
│   ├── audio/
│   │   ├── narration/               # .mp3 narration files
│   │   │   ├── ambient/             # Phase-specific ambient thoughts
│   │   │   ├── flower_collected/    # Reaction to picking a flower
│   │   │   ├── flower_missed/       # Reaction to failed QTE
│   │   │   ├── involuntary_pause/   # Lines during involuntary freezes
│   │   │   ├── phase_enter/         # Phase transition narration
│   │   │   ├── priority/            # Interruptible high-priority lines
│   │   │   └── wrong_key/           # Confusion when pressing old keys
│   │   ├── sfx/
│   │   │   └── flower_success/      # Random success sounds on collection
│   │   └── music/                   # Degraded music
│   ├── textures/
│   │   ├── flowers/                 # Watercolor illustrations (2048×2048 PNG w/ alpha)
│   │   └── grass_wind_noise.tres   # Wind noise texture for grass shader
│   ├── fonts/
│   │   └── game_theme.tres         # Theme with CormorantGaramond font
│   └── 3D/
│       └── ground/
│           └── ground_scene.tscn   # Terrain mesh scene
│
├── EXPERIMENTS/                     # Experimental scripts and scenes
│   ├── EXP_SCRIPTS/
│   │   ├── bouquet_generator.gd    # BouquetGenerator prototype (Node2D)
│   │   ├── autoloads_tests.gd      # Manual testing for clock (SPACE/P keys)
│   │   └── example_game_ending.gd  # Example ending sequence
│   └── flowers_scene.tscn          # Experimental flower scene
│
└── misc/
    └── scripts/                     # Legacy/scratch scripts
        ├── playerOscar.gd
        ├── Camera.gd
        └── camera_box.gd
```

**Not yet created (planned):**
- `systems/bouquet_generator.gd` — Programmatic bouquet image generator
- `resources/flowers/flower_data.gd` — Flyweight Resource per flower type
- `resources/narration/narration_script.gd` — Narration script data
- `shaders/dissolve.gdshader` — Object dissolution

---

## Core Systems

### DeteriorationClock — The Heartbeat

A single float from `0.0` (lucid) to `1.0` (complete dissolution) that drives EVERYTHING.
Game duration: **900 seconds (15 minutes)** in production (`GAME_DURATION` constant).
Currently set to `100.0` for testing — restore to `900.0` before release.
Every system reads this value to know how degraded things should be.

The clock **pauses automatically during QTEs** by connecting to `qte_started` (pauses)
and `qte_completed` (resumes) on the EventBus. It also pauses during involuntary stops
(via `ConfusionSystem` calling `pause()`/`resume()`).

**Thresholds** — special events triggered when crossed:

| Value | Threshold Name      | What Happens                                    |
|-------|---------------------|-------------------------------------------------|
| 0.12  | PHASE_DAWN          | Dawn phase begins — first ambient shift         |
| 0.30  | PHASE_MIDDAY        | Midday — objects start moving, first disruptions |
| 0.50  | PHASE_SUNSET        | Sunset — fog intensifies, colors warm then fade  |
| 0.70  | PHASE_TWILIGHT      | Twilight — heavy degradation, controls scramble  |
| 0.85  | PHASE_EMPTY_NIGHT   | Empty night — near end, final narration begins   |
| 0.92  | PHASE_SKY           | Sky — complete dissolution, game ending          |

### EventBus — Signal Categories

**Currently declared in `game_event_bus.gd`:**

```
Game flow:         game_started, game_ending, game_ended
Deterioration:     deterioration_updated(value: float), deterioration_threshold_reached(threshold_name: StringName)
Phase flow:        phase_changed(new_phase: StringName)
Player actions:    player_interacted(target: Node3D),
                   player_pressed_wrong_key(expected_action: StringName, pressed_key: String)
Confusion:         involuntary_pause_started(duration: float), involuntary_pause_ended
Controls:          controls_remapped(new_map: Dictionary), tutorial_content_changed(new_content: Dictionary)
Flower system:     flower_collected(flower_data: Resource), flower_missed(flower_data: Resource),
                   qte_started(flower: Node3D), qte_completed(success: bool)
Narration:         narration_requested(narration_id: StringName), narration_started(narration_id: StringName),
                   narration_finished(narration_id: StringName)
```

**All signals above are declared and ready to use.** No pending undeclared signals.

### GameStates — The Session Notebook

Stores persistent session data in `autoloads/game_states.gd`. Any system can read,
but only the responsible system should write each piece.

**Key state variables:**
- `collected_flowers: Array[Resource]` — flowers collected this session
- `current_phase: StringName` — current narrative phase (written by PhaseManager)
- `phases_visited: Array[StringName]` — history of visited phases
- `player_speed_multiplier: float` — movement speed factor, 1.0 = normal
  (written by ConfusionSystem, read by player.gd)
- `can_player_move: bool` — false during QTEs, involuntary pauses, cinematics
  (written by ConfusionSystem, read by player.gd)

**Key methods:** `add_flower()`, `get_flower_count()`, `has_collected_any_flower()`,
`reset()`.

### InputManager — The Key to Defamiliarization

The most original system. A translation layer between physical keys and game actions
(Command pattern). Early game: W = forward. Late game: W = ???

Declares `class_name InputManager`. Emits `action_pressed` and `wrong_key_pressed`
signals. Listens for `controls_remapped` from the EventBus to receive new key mappings
from the ConfusionSystem. Also tracks the original mapping to detect "confused" presses
(when the player presses what USED to work).

**Key API methods:**
- `is_action_held(action_name) -> bool` — polling for held keys (movement).
- `get_movement_vector() -> Vector2` — convenience method returning a normalized
  movement vector (replaces `Input.get_vector()` in PlayerController).
- `get_action_key_label(action_name) -> String` — returns current key label for an action.
- `get_all_mappings() -> Dictionary` — returns `{ action_name: key_label }` for tutorial.

**Two types of input:** PRESS actions (interact, tutorial) fire once via `action_pressed`
signal. HELD actions (movement) are polled via `is_action_held()` or `get_movement_vector()`.

**Integration status:** The active player script (`player.gd`) is fully integrated with
the InputManager. It reads movement via `_input_manager.get_movement_vector()` and never
touches raw keyboard input directly. The legacy `player_controller.gd` still exists but
is not used — it reads raw input via `Input.get_vector()` and should not be referenced.

The active `player.gd` also reads `GameStates.can_player_move` to freeze movement
during involuntary pauses and QTEs, and applies `GameStates.player_speed_multiplier`
for deterioration-driven speed reduction.

### PhaseManager — Narrative State Machine

Fully implemented in `scripts/systems/game_phase_manager.gd`. Phases are driven by
DeteriorationClock thresholds, named after times of day:

```
NIGHT → DAWN → MIDDAY → SUNSET → TWILIGHT → EMPTY_NIGHT → SKY
```

Uses a `Phase` enum and a `THRESHOLD_TO_PHASE` dictionary to map threshold names
to phase values. The initial phase is `NIGHT` (stored in `GameStates.current_phase`).
Each phase transition is triggered when the DeteriorationClock crosses the corresponding
threshold. The progression is one-directional — no looping back.

**Special behaviors:**
- On first flower collected (`GameStates.get_flower_count() == 1`): starts the
  DeteriorationClock and transitions to DAWN.
- On `game_ending`: forces transition to SKY if not already there (safety net).
- Each transition updates `GameStates.current_phase` and `GameStates.phases_visited`,
  then emits `phase_changed` on the EventBus.

### InteractionManager — Raycast + QTE Bridge

Manages player interaction via `RayCast3D`. Detects objects in the `"interactables"`
group, shows a crosshair prompt ("E"), and triggers the QTE sequence via `QTEDisplay`.
During a QTE, if the player looks away from the target, the QTE is cancelled.

Flowers use `FlowerPickup` (extends `StaticBody3D`, in `"interactables"` group).
On successful QTE, calls `target.interact()` which plays a random success SFX
(from `assets/audio/sfx/flower_success/`, routed to `"SFX"` audio bus), then
shrinks to zero and `queue_free()`. The SFX player is reparented to the scene
root so it outlives the node being freed. Success sounds are loaded once via
a static cache shared across all `FlowerPickup` instances.

### QTEDisplay — The Collection Challenge

Generates a random key sequence from a QWERTY pool and validates input one key at a
time. Each letter has randomized size variation (±8px) and rotation (±5°). All letters
fade out and shrink over the time limit — if time runs out, the QTE fails.

Emits `qte_completed(success: bool)` as a local signal (not via EventBus).

### FlowerSystem — QTE + Collection (stub)

**Not yet implemented.** Planned to scale QTE difficulty with deterioration:
- Time: 5.0s at 0% → 1.0s at 100%
- Sequence length: 3 keys at 0% → 7 keys at 100%
- Opacity dissolves left-to-right during the QTE display

### GrassField — Procedural Grass System

`@tool` script on a `MultiMeshInstance3D`. Procedurally scatters grass blade quads
across a defined area. Feeds the player's world position to the shader every physics
frame for displacement (grass bends away from the player's feet). Uses
`shaders/grass/grass_v1.gdshader` with wind noise texture.

### ConfusionSystem — Where the Game Unmakes Itself (implemented)

Fully implemented in `scripts/systems/confusion_system.gd`. Listens to `phase_changed`
and `deterioration_updated` to orchestrate three types of degradation:

**1. Involuntary pauses** — The player freezes without warning. A hidden countdown
triggers pauses that freeze both movement (`GameStates.can_player_move = false`) and
the DeteriorationClock. Phase-specific settings control frequency and duration:
- NIGHT/SKY: disabled
- DAWN: 25–40s between, 2–4s duration
- MIDDAY: 18–30s between, 3–6s duration
- SUNSET: 12–22s between, 4–8s duration
- TWILIGHT: 8–15s between, 5–10s duration
- EMPTY_NIGHT: 5–10s between, 6–12s duration

Emits `involuntary_pause_started(duration)` and `involuntary_pause_ended` on EventBus.
Also emits `narration_requested(&"involuntary_pause")` to trigger narration.

**2. Control remapping** — Three presets triggered at specific phases:
- MIDDAY (preset 0): swap forward/back
- SUNSET (preset 1): rotate movement clockwise
- TWILIGHT (preset 2): full scramble
Emits `controls_remapped` on EventBus (InputManager already wired).

**3. Speed reduction** — Exponential curve driven by `deterioration_updated`:
- 0.0 → multiplier 1.0 (full speed)
- 0.5 → multiplier 0.75
- 0.8 → multiplier 0.36
- 1.0 → multiplier 0.05 (nearly frozen)
Writes to `GameStates.player_speed_multiplier`.

**Not yet implemented:**
- Shuffling garden objects when outside player's view frustum

### AmbientPhaseSystem — Theater Lighting Board (implemented)

Fully implemented in `scripts/systems/ambient_phase_system.gd`. Acts as a theater
lighting board — when the phase changes, it smoothly tweens all visual properties.

Listens to `phase_changed` on EventBus. Requires `WorldEnvironment` and
`DirectionalLight3D` assigned via `@export` in the Inspector.

**Properties tweened per phase:**
- `WorldEnvironment`: background energy, ambient color/energy, fog color/density,
  volumetric fog density
- `DirectionalLight3D`: light color, energy, rotation (sun angle)

**Transition durations:**
- Default: 8 seconds (`transition_duration` export)
- DAWN: 1.5x (12s) — cinematic first transition
- SKY: 2.0x (16s) — long final dissolve

Presets define the full visual identity of each phase:
- NIGHT: dark moonlit (bg 0.07, blue ambient)
- DAWN: warm creeping light (orange directional)
- MIDDAY: harsh overexposed (bg 0.6, high energy 1.2)
- SUNSET: golden melancholic (warm fog, low sun angle -10°)
- TWILIGHT: unnatural purple tones (fog density 0.04)
- EMPTY_NIGHT: near void (bg 0.03, minimal light)
- SKY: ethereal blue (bg 1.8, pristine ambient)

### PostProcessSystem — Desaturation + Ghost Bursts (implemented)

Fully implemented in `scripts/systems/post_process_system.gd`. Extends `CanvasLayer`
(layer 100). Drives `shaders/fx/double_vision.gdshader` via shader parameters.

**Two effects:**

**1. Desaturation** — Continuous. Increases with deterioration using a squared curve
(`value * value * 0.85`). Capped at 0.85 so color never fully disappears — a trace
always remains (dignity). Driven by `deterioration_updated`.

**2. Ghost bursts (double vision)** — Episodic. A random timer triggers bursts that
fade in/out. Five deterioration tiers with escalating severity:
- Tier 0 (0.0–0.20): disabled
- Tier 1 (0.20–0.40): rare (20–35s), moderate (0.3–0.5 intensity)
- Tier 2 (0.40–0.60): moderate (12–22s), 0.5–0.7 intensity
- Tier 3 (0.60–0.80): frequent (6–14s), strong (0.6–0.85)
- Tier 4 (0.80–1.0): near constant (2–5s), intense (0.8–1.0)

Requires a `ColorRect` child with `double_vision.gdshader` as material,
assigned via `@export var shader_rect`.

### NarrationSystem — The Florist's Consciousness (implemented)

Fully implemented in `scripts/systems/narration_system.gd`. The narrator is the
florist's inner voice — confused but persistent. Uses the Event Queue pattern: narrations
arrive from many sources but only one plays at a time. If a new one arrives while
another is playing, it waits in line.

Requires an `AudioStreamPlayer` assigned via `@export narration_player`.

**Phase-aware narration:** The same event triggers different voice lines depending on
the current phase. Audio files are organized by category subfolder with phase-prefixed
filenames (e.g., `assets/audio/narration/flower_collected/dawn_01.mp3`). The system
scans all folders on `_ready()` and builds a cache.

**Seven narration categories** (each maps to a subfolder under `assets/audio/narration/`):
- `phase_enter` — plays when a new phase begins
- `flower_collected` — reaction to successful collection
- `flower_missed` — reaction to failed QTE
- `involuntary_pause` — lines during involuntary freezes
- `ambient` — spontaneous thoughts on a timer (see below)
- `wrong_key` — confusion when pressing what used to work (low priority)
- `priority` — high-priority lines that interrupt current playback

**Priority narrations:** IDs `near_end`, `terminal_lucidity`, `final_line` interrupt
whatever is playing and clear the queue.

**Ambient narration:** Between events, the florist thinks out loud. A timer triggers
ambient lines while the player walks. Phase-specific intervals:
- NIGHT: 15–25s
- DAWN: 20–35s
- MIDDAY: 18–30s
- SUNSET: 15–25s
- TWILIGHT: 10–20s
- EMPTY_NIGHT: 8–15s
- SKY: disabled

**Connected EventBus signals:** `narration_requested`, `phase_changed`,
`involuntary_pause_started`, `flower_collected`, `flower_missed`,
`player_pressed_wrong_key`. Emits `narration_started` and `narration_finished`.

### BouquetGenerator — The Final Gift (experimental)

Prototype exists in `EXPERIMENTS/EXP_SCRIPTS/bouquet_generator.gd` (extends `Node2D`).
Planned to use SubViewport to programmatically compose collected watercolor flowers
into a personalized PNG bouquet image. Flowers placed in predefined slots across depth
layers with slight rotation (±15°) for natural composition.

---

## Flower Illustrations — Technical Specifications

15 watercolor botanical illustrations with ink outlines. Commissioned artwork.

**Format:** PNG with alpha channel, letter-size resolution, sRGB, 8 bits per channel.
**Naming:** `flor_[ID]_[nombre].png` (e.g., `flor_01_girasol.png`)

**Composition zones within each illustration:**
- Central zone (60-70%): Flower with petals, leaves, partial stem
- Dissolution zone (15-20%): Watercolor edges fade gradually to alpha 0 (CRITICAL)
- Outer margin (10%): Completely transparent, no pigment touching file edges

**Stem orientation:** All stems point toward lower-center, angle ±15° from vertical.

**The 15 flowers:**

| #  | Name           | Size | Dominant Color        | Unique Feature                      |
|----|----------------|------|-----------------------|-------------------------------------|
| 01 | Girasol        | L    | Vibrant yellow        | Radial disc, solar symmetry         |
| 02 | Dalia          | L    | Burgundy/deep purple  | Geometric petal layers              |
| 03 | Hortensia      | L    | Lavender blue/lilac   | Cloud of tiny flowers               |
| 04 | Ave del paraíso| L    | Orange + electric blue | Bird-in-flight asymmetry            |
| 05 | Peonía         | L    | Intense pink/fuchsia  | Overflowing voluminous petals       |
| 06 | Magnolia       | L    | Creamy white/ivory    | Few large thick petals, open chalice|
| 07 | Rosa           | M    | Classic red/crimson   | Iconic spiral                       |
| 08 | Lirio          | M    | White with freckles   | Trumpet shape, visible stamens      |
| 09 | Tulipán        | M    | Red-yellow bicolor    | Clean cup, minimalist silhouette    |
| 10 | Amapola        | M    | Vivid scarlet         | Paper-thin translucent petals       |
| 11 | Jacinto        | M    | Deep blue/indigo      | Dense compact spike                 |
| 12 | Orquídea       | M    | White with purple veins| Bilateral symmetry, prominent lip  |
| 13 | Cempasúchil    | M    | Intense orange/amber  | Dense curled pompom, Mexican cultural|
| 14 | Lavanda        | M    | Bluish violet         | Tall vertical spike, tiny flowers   |
| 15 | Violeta        | M    | Deep violet           | Small asymmetric petals             |

**Bouquet composition (programmatic):**
1. Each flower is an independent layer on a digital canvas
2. Flowers occupy predefined "slots" in an oval bouquet shape, stems converging at bottom
3. Background flowers: 85-90% opacity, smaller scale. Foreground: full opacity and scale
4. Each flower can be rotated ±15° to break symmetry
5. Dissolution edges allow flowers to overlap without visible hard borders

---

## Game Flow (Minute by Minute)

The DeteriorationClock starts when the player collects their first flower.
Phases are named after times of day, metaphorically representing the florist's
fading consciousness (NIGHT → DAWN → MIDDAY → SUNSET → TWILIGHT → EMPTY_NIGHT → SKY).

```
0:00  NIGHT        — Initial state. Player explores the garden. Deterioration = 0.00
      FIRST FLOWER — Clock starts. QTE sequence for collection.
~1:48 PHASE_DAWN   — 0.12 crossed → Dawn phase, first ambient shift.
~4:30 PHASE_MIDDAY — 0.30 crossed → Objects start shifting. First disruptions.
~7:30 PHASE_SUNSET — 0.50 crossed → Fog intensifies. Colors warm then fade.
~10:30 PHASE_TWILIGHT — 0.70 crossed → Heavy degradation. Controls scramble.
~12:45 PHASE_EMPTY_NIGHT — 0.85 crossed → Near end. Final narration begins.
~13:48 PHASE_SKY   — 0.92 crossed → Complete dissolution narration.
15:00 END          — 1.0 reached → game_ending emitted. Bouquet generated.
```

---

## Signal Flow Diagram

**Current (implemented):**

```
GameDeteriorationClock
  ├── deterioration_updated ──────→ ConfusionSystem (speed reduction)
  │                                → PostProcessSystem (desaturation + ghost tiers)
  ├── deterioration_threshold ───→ PhaseManager (triggers phase transitions)
  ├── listens: qte_started ──────→ pauses clock during QTE
  ├── listens: qte_completed ────→ resumes clock after QTE
  └── emits game_ending when value >= 1.0

PhaseManager
  ├── listens: deterioration_threshold_reached → transitions phase
  ├── listens: flower_collected → starts clock on first flower, transitions to DAWN
  ├── listens: game_ending → forces SKY phase
  └── emits: phase_changed ──────→ AmbientPhaseSystem (tweens visuals)
                                   → ConfusionSystem (pauses + remaps)

ConfusionSystem
  ├── listens: phase_changed → updates pause settings, triggers control remaps
  ├── listens: deterioration_updated → adjusts player_speed_multiplier
  ├── emits: controls_remapped ──→ InputManager (updates translation table)
  ├── emits: involuntary_pause_started/ended → NarrationSystem
  └── emits: narration_requested ──→ NarrationSystem

NarrationSystem
  ├── listens: narration_requested → queues or plays narration
  ├── listens: phase_changed → updates phase, plays phase-enter narration
  ├── listens: involuntary_pause_started → plays involuntary pause narration
  ├── listens: flower_collected → plays collection narration
  ├── listens: flower_missed → plays missed narration
  ├── listens: player_pressed_wrong_key → plays confusion narration
  ├── emits: narration_started → (available for other systems)
  └── emits: narration_finished → (available for other systems)

AmbientPhaseSystem
  └── listens: phase_changed → tweens WorldEnvironment + DirectionalLight3D

PostProcessSystem
  └── listens: deterioration_updated → desaturation curve + ghost burst scheduling

InteractionManager
  ├── raycast detects "interactables" group
  ├── triggers QTEDisplay.start_qte()
  └── on QTEDisplay.qte_completed ──→ calls target.interact()

QTEDisplay
  └── qte_completed (local signal) ──→ InteractionManager

FlowerPickup
  └── interact() called ─────────→ plays random SFX, shrinks, and queue_free()

InputManager
  ├── get_movement_vector() ─────→ Player (movement — integrated)
  ├── action_pressed (local) ────→ Player (interaction)
  ├── wrong_key_pressed ─────────→ GameEventBus.player_pressed_wrong_key
  └── listens: controls_remapped → updates translation table, emits tutorial_content_changed

TutorialDisplay
  └── listens: tutorial_content_changed → updates displayed key labels
```

**Planned (pending system implementation):**

```
ConfusionSystem
  └── objects_shuffled ──────────→ GardenWorld (moves objects — not yet implemented)

FlowerSystem
  ├── qte_started ───────────────→ QTEDisplay (shows sequence)
  ├── qte_completed ─────────────→ PhaseManager (phase transition)
  └── flower_collected ──────────→ GameStates (records flower)
```

---

## Shaders

**Currently implemented:**

- **grass/grass_v1.gdshader** — Procedural grass with wind animation and player
  displacement. Driven by `GrassField` script via `player_position` uniform.
- **fog/fog_garden.gdshader** — Volumetric fog shader with noise-based density,
  flatness, and gradient controls. Applied via `FogVolume` in the garden scene.
- **fx/double_vision.gdshader** — Canvas item shader with two effects: desaturation
  (luminance mix controlled by `desaturation` uniform, 0.0–1.0) and ghost/double
  vision (offset screen copy with horizontal+vertical vibration, controlled by
  `ghost`, `ghost_speed`, `ghost_frequency`, `ghost_amplitude`, `ghost_spread`
  uniforms). Uses screen blend for the ghost overlay. Driven by `PostProcessSystem`.

**Planned (not yet created):**

- **dissolve.gdshader** — Object dissolution (transparency based on noise + deterioration)

Shader parameters should be driven by the deterioration value via script, typically
connecting to `GameEventBus.deterioration_updated`.

PBR material guidelines: Use roughness values carefully to avoid plastic-like appearance.
Download 2K textures from ambientCG or Poly Haven. Manage color space properly (sRGB
for albedo, Linear for roughness/metallic/normal).

---

## Development Practices

### Version Control

- **Git Flow** branching model
- **Conventional Commits** for all commit messages:
  - `feat:` new feature
  - `fix:` bug fix
  - `refactor:` code restructuring
  - `docs:` documentation
  - `style:` formatting (no logic change)
  - `chore:` maintenance
- **Semantic Versioning** (MAJOR.MINOR.PATCH)
- **git-cliff** for automated changelog generation

### Development Phases

1. **Foundations** — Autoloads, EventBus, GameState, DeteriorationClock
2. **Central Engine** — InputManager, PlayerController, ConfusionSystem
3. **Interaction** — FlowerSystem, QTE, flower collection
4. **Narrative** — NarrationSystem, phase-driven audio, reflective phrases
5. **Complete Degradation** — All shaders, visual effects, full control remapping
6. **Closure** — BouquetGenerator, final screen, PNG export

### Key Technical Decisions

- InputManager uses `_unhandled_key_input()` to intercept raw keyboard input before
  Godot's built-in input system processes it.
- The active player script (`player.gd`) reads movement from InputManager and speed
  from `GameStates.player_speed_multiplier`. The legacy `player_controller.gd` still
  exists but is not used.
- Flowers are `StaticBody3D` nodes in the `"interactables"` group (`FlowerPickup`).
- Interaction uses `RayCast3D` from the camera head, managed by `InteractionManager`.
- QTE is handled by `QTEDisplay` (Control node), triggered by `InteractionManager`.
- Mouse look is captured (`Input.MOUSE_MODE_CAPTURED`) with vertical clamping ±90°.
- Camera sway uses `FastNoiseLite` for subtle procedural head movement (configurable
  via `@export` vars: `sway_speed`, `sway_rotation`, `sway_position`).
- Grass uses `MultiMeshInstance3D` with procedural quad generation (`GrassField`).
- Physics engine: Jolt Physics (configured in project.godot).
- Physics tick rate: 30 ticks/second.
- Main scene: `scenes/garden/garden.tscn` (not a separate `main.tscn`).

---

## Artistic Direction

**Tone:** Serene melancholy. Beauty in impermanence. Dignity in the face of loss.

**Visual style:** Watercolor botanical contemporary with ink outlines for the 2D flower
illustrations. 3D garden world with PBR materials, custom terrain meshes from Blender,
and progressive visual degradation (fog, desaturation, transparency).

**Audio:** Female narrator as the florist's inner consciousness. Narration in Spanish.
Music that degrades alongside the visual world (inspired by The Caretaker's "Everywhere
at the End of Time").

**References:**
- *Before Your Eyes* — mechanic as narrative
- *GRIS* — visual beauty in loss
- *That Dragon, Cancer* — empathetic game design
- *The Caretaker* — progressive musical degradation
- Brechtian defamiliarization techniques

---

## Constraints and Deadlines

- **Budget:** $62,000 MXN (PECDA scholarship)
- **Deadline:** April 30, 2026
- **Duration target:** 15–20 minute experience
- **Max flowers in world:** 15
- **Max flowers collectible:** 15 (player can choose which ones)
- **Game timer:** 900 seconds (15 minutes)

---

## Common Pitfalls to Avoid

1. **Never reference autoloads by class_name in code** — use their registered names
   (`GameEventBus`, `GameStates`, `GameDeteriorationClock`).
2. **Never let the player script read raw input** — always go through InputManager.
   The active `player.gd` is already integrated; the legacy `player_controller.gd`
   should not be used.
3. **Never create direct references between systems** — use EventBus signals.
4. **Never mix Spanish into code** — only English in GDScript.
5. **Never use `&&`, `||`, `!`** — use `and`, `or`, `not`.
6. **Never omit static typing** — every variable, parameter, and return type must be typed.
7. **Never forget trailing commas** in multiline arrays/dicts/enums.
8. **Never hard-code deterioration checks** in individual systems — always listen to
   threshold signals from DeteriorationClock via EventBus.
9. **Watercolor borders must dissolve naturally** — never hard-cut or mask digitally.
10. **The bouquet is the game's final gift** — it must feel personal and beautiful regardless
    of how many flowers the player collected.
