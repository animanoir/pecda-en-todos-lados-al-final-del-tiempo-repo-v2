# bouquet_generator.gd
# Attach this script to the root Node2D of the BouquetGenerator scene.
#
# SCENE SETUP (create these nodes in the editor):
#
# BouquetGenerator (Node2D) ← this script
#   └── SubViewport (SubViewport)
#         ├── Background (TextureRect)
#         └── FlowerContainer (Node2D)
#
# SubViewport settings in the Inspector:
#   - Size: 2048 x 2048 (or your desired output resolution)
#   - Transparent BG: ON (checked)
#   - Render Target > Update Mode: ALWAYS (while composing), then DISABLED

extends Node2D
class_name BouquetGenerator

# ── Configuration ──

## Output image resolution (square).
@export var output_size: int = 2048

## Maximum number of flowers the player can collect.
@export var max_flowers: int = 15

## How much to shrink flowers in the back layer (0.8 = 80% of original size).
@export var back_scale: float = 0.8

## How much to shrink flowers in the mid layer.
@export var mid_scale: float = 0.9

## Opacity for flowers in the back layer (0.0 - 1.0).
@export var back_opacity: float = 0.85

## Opacity for flowers in the mid layer.
@export var mid_opacity: float = 0.92

## Maximum random rotation in degrees (applied as ±value).
@export var max_rotation_degrees: float = 15.0

## Vertical offset to push the whole arrangement upward (stems converge below center).
@export var vertical_offset: float = -0.08

# ── Node References ──

@onready var sub_viewport: SubViewport = $SubViewport
@onready var flower_container: Node2D = $SubViewport/FlowerContainer

# ── Internal State ──

# Array of textures (the flower PNGs the player collected during the game).
var _collected_flowers: Array[Texture2D] = []

# Predefined slot positions for up to 15 flowers, organized in 3 depth layers.
# Positions are in normalized coordinates (0.0 to 1.0), where (0.5, 0.5) is center.
# They will be multiplied by output_size to get pixel positions.
var _slot_layout: Array[Dictionary] = []


func _ready() -> void:
	_build_slot_layout()
	# Make sure the SubViewport matches our desired output size.
	sub_viewport.size = Vector2i(output_size, output_size)


# ════════════════════════════════════════════════════════════════════════════
# PUBLIC API
# ════════════════════════════════════════════════════════════════════════════

## Call this every time the player picks up a flower during gameplay.
## [param flower_texture] The preloaded Texture2D of the flower PNG.
func add_flower(flower_texture: Texture2D) -> void:
	if _collected_flowers.size() >= max_flowers:
		push_warning("BouquetGenerator: Max flowers reached (%d)." % max_flowers)
		return
	_collected_flowers.append(flower_texture)


## Returns how many flowers have been collected so far.
func get_flower_count() -> int:
	return _collected_flowers.size()


## Composes the bouquet and saves it as a PNG file.
## Call this at the end of the game.
## [param save_path] Where to save the PNG (e.g., "user://my_bouquet.png").
## [param phrase] The reflective phrase to overlay at the bottom.
## Returns the Image object so you can also display it in-game.
func generate_bouquet(save_path: String, phrase: String = "") -> Image:
	# 1. Clear any previous composition.
	_clear_container()

	# 2. Place each collected flower into a slot.
	_place_flowers()

	# 3. Wait two frames so the SubViewport renders everything.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	# 4. Grab the rendered image from the SubViewport.
	var image: Image = sub_viewport.get_texture().get_image()

	# 5. Overlay the reflective phrase onto the image (if provided).
	if phrase != "":
		image = await _overlay_phrase(image, phrase)

	# 6. Save to disk.
	var error := image.save_png(save_path)
	if error != OK:
		push_error("BouquetGenerator: Failed to save image. Error: %d" % error)
	else:
		print("BouquetGenerator: Bouquet saved to %s" % save_path)

	return image


# ════════════════════════════════════════════════════════════════════════════
# SLOT LAYOUT
# ════════════════════════════════════════════════════════════════════════════

## Builds the predefined arrangement of slots.
## Each slot has: position (normalized), layer (back/mid/front), and z_index.
##
## The layout forms an inverted teardrop / oval:
##   - Back layer (3 slots):  top of the oval, smaller, more transparent.
##   - Mid layer (5 slots):   middle ring, medium size.
##   - Front layer (7 slots): lower area, full size and opacity.
##
## You can adjust these positions to taste. The coordinate system:
##   (0.0, 0.0) = top-left     (1.0, 1.0) = bottom-right
##   (0.5, 0.5) = center
func _build_slot_layout() -> void:
	var v := vertical_offset  # Shift everything up so stems have room below.

	# ── BACK LAYER (drawn first, behind everything) ──
	# 3 slots across the top of the oval.
	_slot_layout.append({ "pos": Vector2(0.35, 0.25 + v), "layer": "back", "z": 0 })
	_slot_layout.append({ "pos": Vector2(0.50, 0.20 + v), "layer": "back", "z": 0 })
	_slot_layout.append({ "pos": Vector2(0.65, 0.25 + v), "layer": "back", "z": 0 })

	# ── MID LAYER ──
	# 5 slots forming the widest part of the oval.
	_slot_layout.append({ "pos": Vector2(0.25, 0.38 + v), "layer": "mid", "z": 1 })
	_slot_layout.append({ "pos": Vector2(0.40, 0.35 + v), "layer": "mid", "z": 1 })
	_slot_layout.append({ "pos": Vector2(0.55, 0.33 + v), "layer": "mid", "z": 1 })
	_slot_layout.append({ "pos": Vector2(0.70, 0.37 + v), "layer": "mid", "z": 1 })
	_slot_layout.append({ "pos": Vector2(0.50, 0.42 + v), "layer": "mid", "z": 2 })

	# ── FRONT LAYER (drawn last, on top of everything) ──
	# 7 slots forming the lower/center area, where the bouquet feels fullest.
	_slot_layout.append({ "pos": Vector2(0.30, 0.50 + v), "layer": "front", "z": 3 })
	_slot_layout.append({ "pos": Vector2(0.45, 0.48 + v), "layer": "front", "z": 3 })
	_slot_layout.append({ "pos": Vector2(0.60, 0.50 + v), "layer": "front", "z": 3 })
	_slot_layout.append({ "pos": Vector2(0.38, 0.58 + v), "layer": "front", "z": 4 })
	_slot_layout.append({ "pos": Vector2(0.55, 0.56 + v), "layer": "front", "z": 4 })
	_slot_layout.append({ "pos": Vector2(0.70, 0.55 + v), "layer": "front", "z": 3 })
	_slot_layout.append({ "pos": Vector2(0.48, 0.65 + v), "layer": "front", "z": 5 })


# ════════════════════════════════════════════════════════════════════════════
# COMPOSITION
# ════════════════════════════════════════════════════════════════════════════

## Removes all previously placed flower sprites from the container.
func _clear_container() -> void:
	for child in flower_container.get_children():
		child.queue_free()


## Places each collected flower as a Sprite2D inside the SubViewport.
func _place_flowers() -> void:
	# Shuffle the slot order slightly so repeating the game feels different,
	# but keep layer ordering intact (back slots filled first).
	var available_slots := _slot_layout.duplicate()

	# Sort by z so back-layer slots are assigned first.
	# The func inside is a lambda function.
	available_slots.sort_custom(func(a, b): return a["z"] < b["z"])

	# Only use as many slots as we have flowers.
	var count := mini(_collected_flowers.size(), available_slots.size())

	for i in range(count):
		var flower_tex: Texture2D = _collected_flowers[i]
		var slot: Dictionary = available_slots[i]

		var sprite := Sprite2D.new()
		sprite.texture = flower_tex
		sprite.centered = true

		# ── Position ──
		# Convert normalized (0-1) coordinates to pixel coordinates.
		var pixel_pos:Vector2 = slot["pos"] * float(output_size)
		sprite.position = pixel_pos

		# ── Depth ──
		sprite.z_index = slot["z"]

		# ── Scale ──
		# Flowers are 2048x2048 source. We need to fit them within the composition.
		# Base scale: each flower occupies ~30% of the canvas at "full size."
		var base_fit := float(output_size) * 0.30 / float(flower_tex.get_width())
		var layer_multiplier := _get_layer_scale(slot["layer"])
		sprite.scale = Vector2.ONE * base_fit * layer_multiplier

		# ── Opacity ──
		sprite.modulate.a = _get_layer_opacity(slot["layer"])

		# ── Rotation ──
		# Random rotation between -max_rotation and +max_rotation degrees.
		var angle := randf_range(-max_rotation_degrees, max_rotation_degrees)
		sprite.rotation_degrees = angle

		flower_container.add_child(sprite)


## Returns the scale multiplier for a given layer.
func _get_layer_scale(layer: String) -> float:
	match layer:
		"back":
			return back_scale
		"mid":
			return mid_scale
		"front":
			return 1.0
		_:
			return 1.0


## Returns the opacity for a given layer.
func _get_layer_opacity(layer: String) -> float:
	match layer:
		"back":
			return back_opacity
		"mid":
			return mid_opacity
		"front":
			return 1.0
		_:
			return 1.0


# ════════════════════════════════════════════════════════════════════════════
# PHRASE OVERLAY
# ════════════════════════════════════════════════════════════════════════════

## Draws the reflective phrase at the bottom of the bouquet image.
## This modifies the Image directly (CPU-side) using a secondary viewport.
func _overlay_phrase(base_image: Image, phrase: String) -> Image:
	# Strategy: create a temporary Label in a second SubViewport,
	# render it, and blend it onto the base image.
	#
	# For a simpler approach, you can skip this and add the phrase
	# as a UI element when displaying the image to the player.
	# This method bakes it into the PNG itself.

	var phrase_viewport := SubViewport.new()
	phrase_viewport.size = Vector2i(output_size, 200)
	phrase_viewport.transparent_bg = true
	phrase_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE

	var label := Label.new()
	label.text = phrase
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.size = Vector2(output_size, 200)
	label.add_theme_font_size_override("font_size", 48)
	label.add_theme_color_override("font_color", Color(0.2, 0.15, 0.1, 0.9))

	phrase_viewport.add_child(label)
	add_child(phrase_viewport)

	# Wait for the phrase to render.
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw

	var phrase_image: Image = phrase_viewport.get_texture().get_image()

	# Blend the phrase onto the bottom of the base image.
	var paste_y := output_size - 250
	base_image.blend_rect(phrase_image, Rect2i(Vector2i.ZERO, phrase_image.get_size()), Vector2i(0, paste_y))

	# Clean up.
	phrase_viewport.queue_free()

	return base_image


# ════════════════════════════════════════════════════════════════════════════
# UTILITY
# ════════════════════════════════════════════════════════════════════════════

## Clears all collected flowers (e.g., for a new game).
func reset() -> void:
	_collected_flowers.clear()
	_clear_container()
