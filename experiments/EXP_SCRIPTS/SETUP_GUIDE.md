# Bouquet Generation System — Setup Guide
# For: "En todos lados al final del tiempo"
# Engine: Godot 4.x

## Step-by-step: Creating the Scene in Godot Editor

### 1. Create the scene file

- File → New Scene
- Select "Node2D" as root node
- Rename it to **BouquetGenerator**
- Save as `res://scenes/bouquet_generator.tscn`

### 2. Add the SubViewport

- Select BouquetGenerator → Add Child Node → **SubViewport**
- In the Inspector, set:
  - `Size`: 2048 x 2048
  - `Transparent BG`: ✅ checked
  - `Render Target > Update Mode`: Always

### 3. Add children inside the SubViewport

Inside the SubViewport, add:

- **TextureRect** (rename to `Background`)
  - Optional: assign a paper texture here for the bouquet background
  - Set `Size`: 2048 x 2048
  - If you don't want a background, skip this or leave it transparent

- **Node2D** (rename to `FlowerContainer`)
  - This stays empty — the script creates Sprite2D children dynamically

### 4. Attach the script

- Select BouquetGenerator (root)
- Attach script → select `bouquet_generator.gd`

### 5. Final node tree should look like:

```
BouquetGenerator (Node2D) ← bouquet_generator.gd
  └── SubViewport (SubViewport)
        ├── Background (TextureRect) ← optional paper texture
        └── FlowerContainer (Node2D) ← flowers go here dynamically
```

### 6. Import settings for flower PNGs

For each flower PNG in `res://assets/flowers/`:

- Select the .png file in the FileSystem panel
- Go to the Import tab (next to Scene tab, top-left)
- Make sure:
  - `Compress > Mode`: Lossless (to preserve transparency quality)
  - `Mipmaps > Generate`: OFF (not needed for 2D composition)
  - `Process > Fix Alpha Border`: ON (prevents dark edges on transparency)
- Click "Reimport"

### 7. How to call it from your game

```gdscript
# Somewhere in your game, keep a reference:
var bouquet_gen: BouquetGenerator

# When the player picks a flower:
var tex = load("res://assets/flowers/flor_07_rosa.png")
bouquet_gen.add_flower(tex)

# When the game ends:
var image = await bouquet_gen.generate_bouquet(
    "user://mi_ramo.png",
    "Las manos recuerdan lo que la mente olvida."
)
```

## How It Works (Visual Explanation)

```
SUBVIEWPORT (2048 x 2048 pixels, transparent)
┌──────────────────────────────────────────────┐
│                                              │
│         🌻  🌸  🌺     ← BACK LAYER         │
│        (small, 85% opacity, z=0)             │
│                                              │
│      🌷  🌹  🌼  🪻    ← MID LAYER          │
│     (medium, 92% opacity, z=1-2)             │
│                                              │
│    🌺  🌸  🌻  🌹  💐  ← FRONT LAYER        │
│   (full size, 100% opacity, z=3-5)           │
│                                              │
│           │ │ │ │ │    ← Stems converge      │
│           └─┴─┴─┘                            │
│                                              │
│  "Cada pétalo fue un momento. El ramo eres   │
│   tú."                   ← PHRASE            │
│                                              │
└──────────────────────────────────────────────┘
            ↓
    image.save_png("user://mi_ramo.png")
            ↓
    Player gets a unique PNG file 🎁
```

## Customization Tips

### Adjusting the layout
The `_build_slot_layout()` function defines all 15 slot positions.
Each slot is a Dictionary with:
- `"pos"`: Vector2 in normalized coordinates (0.0-1.0)
- `"layer"`: "back", "mid", or "front"
- `"z"`: z_index for draw order

To adjust: change the Vector2 values and re-run. Use the
preview TextureRect to see results in real time during development.

### Adding a paper texture background
Assign a texture to the Background TextureRect node.
A subtle aged paper or watercolor paper texture works well.
Make sure it's also 2048x2048 to match the output.

### Different bouquet shapes
The current layout is an oval. You could create alternative
layouts (circular, cascading, crescent) by changing the
positions in `_build_slot_layout()`. Consider making multiple
layout presets and picking one randomly for replayability.

### Flower size categories
The current code uses a uniform base scale. To respect the
G/M size categories from the spec:

```gdscript
# In _place_flowers(), after creating the sprite:
var category_scale := 1.0
if flower_id in LARGE_FLOWERS:
	category_scale = 1.15   # 15% bigger
elif flower_id in MEDIUM_FLOWERS:
	category_scale = 0.90   # 10% smaller

sprite.scale = Vector2.ONE * base_fit * layer_multiplier * category_scale
```

To do this, you'd need to pass the flower ID alongside the
texture when calling add_flower(), or store it in a Dictionary.
