# example_game_ending.gd
# Example: how to use BouquetGenerator at the end of the game.
#
# This is NOT a file you copy directly — it shows the pattern
# of how your game logic calls the bouquet system.

extends Node

# Reference to the BouquetGenerator scene (instantiate it or have it in the tree).
@onready var bouquet: BouquetGenerator = $BouquetGenerator

# Reference to a TextureRect in your UI to show the final image.
@onready var result_display: TextureRect = $UI/ResultDisplay

# Reference to a Label for the phrase.
@onready var phrase_label: Label = $UI/PhraseLabel


# ── DURING GAMEPLAY ──
# Every time the player picks up a flower, call this.
# The flower_id corresponds to your flower catalog (e.g., "flor_01_girasol").

func _on_player_picked_flower(flower_id: String) -> void:
	# Load the flower texture from your resources folder.
	var path := "res://assets/flowers/%s.png" % flower_id
	var texture := load(path) as Texture2D

	if texture == null:
		push_error("Could not load flower texture: %s" % path)
		return

	bouquet.add_flower(texture)
	print("Flower collected: %s (%d total)" % [flower_id, bouquet.get_flower_count()])


# ── AT THE END OF THE GAME ──
# When the experience concludes and it's time to generate the bouquet.

func _on_game_ending() -> void:
	# Pick a reflective phrase (could be random, based on flowers, etc.)
	var phrases := [
		"Lo que florece en ti no necesita recordarse para ser real.",
		"Un jardín no desaparece porque cierres los ojos.",
		"Cada pétalo fue un momento. El ramo eres tú.",
		"Lo hermoso no pide permiso para existir.",
		"Las manos recuerdan lo que la mente olvida.",
	]
	var phrase: String = phrases.pick_random()

	# Generate the bouquet and save it.
	# "user://" maps to the player's local app data folder.
	var save_path := "user://mi_ramo_final.png"
	var result_image: Image = await bouquet.generate_bouquet(save_path, phrase)

	# Display the result on screen.
	var display_texture := ImageTexture.create_from_image(result_image)
	result_display.texture = display_texture
	phrase_label.text = phrase

	# Optional: also tell the player where the file was saved.
	var absolute_path := ProjectSettings.globalize_path(save_path)
	print("Bouquet saved at: %s" % absolute_path)


# ── FOLDER STRUCTURE ──
# Your project's flower assets should look like:
#
# res://
#   assets/
#     flowers/
#       flor_01_girasol.png        (2048x2048, transparent BG)
#       flor_02_dalia.png
#       flor_03_hortensia.png
#       flor_04_ave_del_paraiso.png
#       flor_05_peonia.png
#       flor_06_magnolia.png
#       flor_07_rosa.png
#       flor_08_lirio.png
#       flor_09_tulipan.png
#       flor_10_amapola.png
#       flor_11_jacinto.png
#       flor_12_orquidea.png
#       flor_13_cempasuchil.png
#       flor_14_lavanda.png
#       flor_15_violeta.png
#   scenes/
#     bouquet_generator.tscn       (the BouquetGenerator scene)
#   scripts/
#     bouquet_generator.gd         (the main script)
