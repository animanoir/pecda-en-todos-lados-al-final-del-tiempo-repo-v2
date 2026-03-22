extends CanvasLayer
## The final screen — the game's gift to the player.
##
## When the game ends, this screen fades in and displays
## a bouquet composed of the watercolor illustrations of
## every flower the player collected. The bouquet looks
## beautiful whether it has 3 flowers or 15.
##
## The composition arranges flowers in an oval shape with
## stems converging at the bottom. Large flowers go in the
## center, medium flowers fill around them. Each flower is
## slightly rotated (±15°) for a natural, handmade feel.
##
## A short reflective phrase appears below the bouquet.
## This phrase is the same regardless of how many flowers
## were collected — dignity does not depend on performance.
##
## SETUP:
## 1. Create a CanvasLayer in your scene (layer = 100).
## 2. Add the node structure described below.
## 3. Assign this script to the CanvasLayer.
## 4. It connects to the EventBus automatically.
##
## SCENE STRUCTURE:
## BouquetScreen (CanvasLayer) ← this script
## └── Background (ColorRect) — full screen, dark
##     └── MarginContainer
##         └── VBoxContainer
##             ├── BouquetContainer (Control) — where flowers go
##             └── PhraseLabel (Label) — the reflective phrase


# ---------------------------------------------------------------
# Export variables
# ---------------------------------------------------------------

## The dark background that covers the screen.
@export var background: ColorRect

## The container where flower illustrations will be placed.
@export var bouquet_container: Control

## The label showing the reflective phrase.
@export var phrase_label: Label

## How long the fade-in takes (in seconds).
@export var fade_duration: float = 3.0


# ---------------------------------------------------------------
# Constants
# ---------------------------------------------------------------

## The reflective phrase shown below the bouquet.
## Same phrase regardless of performance — dignity remains.
const FINAL_PHRASE: String = "Para ti, que fuiste todo."

## Predefined slots where flowers will be placed.
## Positions are in percentage of the container size (0.0–1.0).
## Each slot has: position, scale, rotation, and depth order.
## Slots are filled in order: first the large flowers (center),
## then medium flowers (around them).
const BOUQUET_SLOTS: Array[Dictionary] = [
	# --- Large flower slots (center, bigger) ---
	{
		"position": Vector2(0.50, 0.35),
		"scale": 0.45,
		"rotation": -3.0,
		"order": 0,
		"size": "Large",
	},
	{
		"position": Vector2(0.35, 0.40),
		"scale": 0.40,
		"rotation": -12.0,
		"order": 1,
		"size": "Large",
	},
	{
		"position": Vector2(0.65, 0.38),
		"scale": 0.42,
		"rotation": 8.0,
		"order": 1,
		"size": "Large",
	},
	{
		"position": Vector2(0.42, 0.25),
		"scale": 0.38,
		"rotation": 5.0,
		"order": 2,
		"size": "Large",
	},
	{
		"position": Vector2(0.58, 0.28),
		"scale": 0.36,
		"rotation": -7.0,
		"order": 2,
		"size": "Large",
	},
	{
		"position": Vector2(0.50, 0.50),
		"scale": 0.35,
		"rotation": 2.0,
		"order": 3,
		"size": "Large",
	},
	# --- Medium flower slots (around, smaller) ---
	{
		"position": Vector2(0.25, 0.45),
		"scale": 0.30,
		"rotation": -15.0,
		"order": 3,
		"size": "Medium",
	},
	{
		"position": Vector2(0.75, 0.43),
		"scale": 0.30,
		"rotation": 14.0,
		"order": 3,
		"size": "Medium",
	},
	{
		"position": Vector2(0.30, 0.55),
		"scale": 0.28,
		"rotation": -10.0,
		"order": 4,
		"size": "Medium",
	},
	{
		"position": Vector2(0.70, 0.53),
		"scale": 0.28,
		"rotation": 11.0,
		"order": 4,
		"size": "Medium",
	},
	{
		"position": Vector2(0.45, 0.60),
		"scale": 0.26,
		"rotation": 4.0,
		"order": 5,
		"size": "Medium",
	},
	{
		"position": Vector2(0.55, 0.58),
		"scale": 0.26,
		"rotation": -6.0,
		"order": 5,
		"size": "Medium",
	},
	{
		"position": Vector2(0.20, 0.55),
		"scale": 0.24,
		"rotation": -13.0,
		"order": 6,
		"size": "Medium",
	},
	{
		"position": Vector2(0.80, 0.52),
		"scale": 0.24,
		"rotation": 12.0,
		"order": 6,
		"size": "Medium",
	},
	{
		"position": Vector2(0.50, 0.65),
		"scale": 0.22,
		"rotation": 1.0,
		"order": 7,
		"size": "Medium",
	},
]

## Background color for the bouquet screen.
const BG_COLOR: Color = Color(0.02, 0.02, 0.04, 1.0)

## Size of each flower illustration in pixels (will be scaled).
const FLOWER_BASE_SIZE: float = 400.0


# ---------------------------------------------------------------
# Private variables
# ---------------------------------------------------------------

var _is_showing: bool = false


# ---------------------------------------------------------------
# Virtual callbacks
# ---------------------------------------------------------------

func _ready() -> void:
	# Start hidden.
	visible = false
	_is_showing = false

	# Set this layer above everything.
	layer = 110

	# Listen for game ending.
	GameEventBus.game_ending.connect(_on_game_ending)

	# Set initial state.
	if background:
		background.color = Color(BG_COLOR.r, BG_COLOR.g, BG_COLOR.b, 0.0)

	if phrase_label:
		phrase_label.text = ""
		phrase_label.modulate.a = 0.0


# ---------------------------------------------------------------
# Private methods
# ---------------------------------------------------------------

func _show_bouquet() -> void:
	## Composes and reveals the bouquet screen.
	_is_showing = true
	visible = true

	# Freeze the player.
	GameStates.can_player_move = false

	# Get collected flowers from GameStates.
	var flowers: Array[Resource] = GameStates.collected_flowers

	# Compose the bouquet.
	_compose_flowers(flowers)

	# Fade in the background.
	if background:
		var tween: Tween = create_tween()
		tween.tween_property(
				background, "color:a", 1.0, fade_duration
		)

	# Fade in the phrase after the background.
	if phrase_label:
		phrase_label.text = FINAL_PHRASE

		# Center the text.
		phrase_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

		var tween: Tween = create_tween()
		tween.tween_interval(fade_duration + 1.0)
		tween.tween_property(
				phrase_label, "modulate:a", 1.0, 2.0
		)

	# Emit game_ended after everything is visible.
	var end_tween: Tween = create_tween()
	end_tween.tween_interval(fade_duration + 4.0)
	end_tween.tween_callback(
			func() -> void: GameEventBus.game_ended.emit()
	)

	print("[BOUQUET] Showing bouquet with %d flowers." % flowers.size())


func _compose_flowers(flowers: Array[Resource]) -> void:
	## Places flower illustrations in the bouquet container.
	## Each flower gets a TextureRect positioned in a predefined slot.

	if not bouquet_container:
		return

	# Clear any previous composition.
	for child: Node in bouquet_container.get_children():
		child.queue_free()

	# Separate flowers by size category.
	var large_flowers: Array[Resource] = []
	var medium_flowers: Array[Resource] = []

	for flower: Resource in flowers:
		if flower is FlowerData:
			var data: FlowerData = flower as FlowerData
			if data.size_category == "Large":
				large_flowers.append(data)
			else:
				medium_flowers.append(data)
		else:
			# Fallback for test resources without FlowerData.
			medium_flowers.append(flower)

	# Fill slots: large first, then medium.
	var all_flowers: Array[Resource] = []
	all_flowers.append_array(large_flowers)
	all_flowers.append_array(medium_flowers)

	var container_size: Vector2 = bouquet_container.size

	for i: int in range(mini(all_flowers.size(), BOUQUET_SLOTS.size())):
		var flower: Resource = all_flowers[i]
		var slot: Dictionary = BOUQUET_SLOTS[i]

		var tex_rect := TextureRect.new()

		# Try to get the illustration from FlowerData.
		if flower is FlowerData:
			var data: FlowerData = flower as FlowerData
			if data.illustration:
				tex_rect.texture = data.illustration
			else:
				# No illustration yet — create a colored placeholder.
				tex_rect.texture = _create_placeholder_texture(
						data.dominant_color
				)
		else:
			# Test resource — use white placeholder.
			tex_rect.texture = _create_placeholder_texture(
					Color(0.8, 0.6, 0.7)
			)

		# Configure the TextureRect.
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL

		# Calculate size and position from the slot.
		var flower_size: float = FLOWER_BASE_SIZE * slot.get("scale", 0.3)
		tex_rect.custom_minimum_size = Vector2(flower_size, flower_size)
		tex_rect.size = Vector2(flower_size, flower_size)

		var slot_pos: Vector2 = slot.get("position", Vector2(0.5, 0.5))
		tex_rect.position = Vector2(
				slot_pos.x * container_size.x - flower_size * 0.5,
				slot_pos.y * container_size.y - flower_size * 0.5,
		)

		# Apply rotation.
		tex_rect.rotation_degrees = slot.get("rotation", 0.0)

		# Set the pivot to the center for proper rotation.
		tex_rect.pivot_offset = Vector2(flower_size * 0.5, flower_size * 0.5)

		# Start invisible, will fade in.
		tex_rect.modulate.a = 0.0

		bouquet_container.add_child(tex_rect)

		# Stagger the fade-in: each flower appears slightly later.
		var delay: float = fade_duration + 0.3 * float(i)
		var flower_tween: Tween = create_tween()
		flower_tween.tween_interval(delay)
		flower_tween.tween_property(
				tex_rect, "modulate:a", 1.0, 1.0
		)


func _create_placeholder_texture(color: Color) -> Texture2D:
	## Creates a simple colored circle texture as placeholder
	## when the watercolor illustration isn't available yet.
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var center := Vector2(128.0, 128.0)

	for x: int in range(256):
		for y: int in range(256):
			var pos := Vector2(float(x), float(y))
			var dist: float = pos.distance_to(center)
			if dist < 100.0:
				# Solid center.
				image.set_pixel(x, y, color)
			elif dist < 120.0:
				# Soft edge fade.
				var alpha: float = 1.0 - (dist - 100.0) / 20.0
				var faded := Color(color.r, color.g, color.b, alpha)
				image.set_pixel(x, y, faded)
			else:
				image.set_pixel(x, y, Color(0, 0, 0, 0))

	return ImageTexture.create_from_image(image)


# ---------------------------------------------------------------
# Signal callbacks
# ---------------------------------------------------------------

func _on_game_ending() -> void:
	## The deterioration clock hit 1.0. Show the bouquet.
	_show_bouquet()
