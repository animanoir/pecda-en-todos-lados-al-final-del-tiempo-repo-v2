class_name FlowerData
extends Resource
## Shared data for a single flower type (Flyweight pattern).
##
## Each of the 15 flower types has ONE FlowerData resource.
## Every FlowerPickup in the garden references one of these.
## When the player collects a flower, this resource is what
## gets stored in GameStates.collected_flowers.
##
## CREATE IN EDITOR:
## 1. Right-click in FileSystem → New Resource → FlowerData.
## 2. Fill in the fields in the Inspector.
## 3. Save as "flower_data_[name].tres" in resources/flowers/.


## The flower's display name (in Spanish, for the player).
## Example: "Girasol", "Dalia", "Violeta"
@export var flower_name: String = ""

## Unique identifier number (1–15).
@export var flower_id: int = 0

## The 2D watercolor illustration for the bouquet.
## This is the PNG with alpha that Lilian is painting.
## Example: "res://assets/textures/flowers/flor_01_girasol.png"
## Leave empty if the illustration isn't ready yet —
## the BouquetScreen will use a placeholder.
@export var illustration: Texture2D = null

## Size category. Large flowers go in the center/back,
## medium flowers fill in around them.
@export_enum("Large", "Medium") var size_category: String = "Medium"

## The dominant color of this flower (for visual fallback
## when illustration isn't available, and for tinting effects).
@export var dominant_color: Color = Color.WHITE
