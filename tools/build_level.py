#!/usr/bin/env python3
"""Layout for the platformer level.

This file is the single source of truth: it writes levels/level_layout.json, which
tools/build_level.gd paints into the TileMap, and renders a preview of exactly
the same cells into artifacts/level_preview.png.
"""

import json
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TILE = 64
COLS = 32          # 2048 px wide, twice the 1000 px viewport as in the lab
ROWS = 11          # 704 px tall
GROUND_ROW = 8     # first solid row of the ground
GROUND_Y = GROUND_ROW * TILE   # 512 - the surface the player walks on

tiles = []          # (col, row, tile_name)
decor = []          # (texture, center_x, bottom_y)
collectibles = []   # (kind, center_x, center_y)


def put(c, r, name):
    tiles.append({"x": c, "y": r, "tile": name})


def span(first, last, top_row, bottom_row, grass=True, bottom_caps=True):
    """Horizontal slab of dirt with grass on top and optional rounded feet."""
    for c in range(first, last + 1):
        for r in range(top_row, bottom_row + 1):
            if r == top_row:
                if not grass:
                    name = "dirt_left" if c == first else "dirt_right" if c == last else "dirt"
                elif c == first and c == last:
                    name = "grass_top"
                elif c == first:
                    name = "grass_top_left"
                elif c == last:
                    name = "grass_top_right"
                else:
                    name = "grass_top"
            elif r == bottom_row and bottom_caps:
                if c == first and c == last:
                    name = "dirt_bottom"
                elif c == first:
                    name = "dirt_bottom_left"
                elif c == last:
                    name = "dirt_bottom_right"
                else:
                    name = "dirt_bottom"
            else:
                if c == first:
                    name = "dirt_left"
                elif c == last:
                    name = "dirt_right"
                else:
                    name = "dirt"
            put(c, r, name)


# ---------------------------------------------------------------- ground ----
# Five slabs separated by the gaps the player has to jump.
# gaps: col 6, cols 11-12, cols 18-20, cols 26-27
GROUND_SPANS = [(0, 5), (7, 10), (13, 17), (21, 25), (28, 31)]
for first, last in GROUND_SPANS:
    span(first, last, GROUND_ROW, ROWS - 1, bottom_caps=False)

# -------------------------------------------------------------- platforms ----
# Raised plateaus, two tiles tall (rows 6-7), so the top sits one jump above
# the ground. They are the ledges the collectibles sit on.
PLATEAUS = [(9, 10), (23, 24)]
for first, last in PLATEAUS:
    span(first, last, 6, 7, bottom_caps=False)

# A pillar island in the middle of the wide gap (columns 18-20): it turns the
# three tile pit into two short hops.
span(19, 19, GROUND_ROW, ROWS - 1, bottom_caps=False)

# ------------------------------------------------------------ boundaries ----
# Dirt columns at both ends so the player cannot walk out of the level.
for r in range(4, GROUND_ROW):
    put(0, r, "dirt")
    put(COLS - 1, r, "dirt")

# --------------------------------------------------------------- objects ----
def floor_y(col):
    """Top of the solid tile the player stands on at this column."""
    c = col
    if c == 0:
        c = 1
    if c == COLS - 1:
        c = COLS - 2
    for r in range(ROWS):
        if any(t["x"] == c and t["y"] == r for t in tiles):
            return r * TILE
    return GROUND_Y


DECOR = [
    ("obj_tree", 3), ("obj_bush", 4), ("obj_tree_2", 16),
    ("obj_stump", 14), ("obj_bush_small", 17), ("obj_tree", 22),
    ("obj_bush", 25), ("obj_sign", 30), ("obj_tree_2", 29),
]
for texture, col in DECOR:
    decor.append({"texture": texture, "x": col * TILE + TILE // 2,
                  "y": floor_y(col)})

# ---------------------------------------------------------- collectibles ----
def on_ground(col, kind):
    collectibles.append({"kind": kind, "x": col * TILE + TILE // 2,
                         "y": floor_y(col) - 22})


collectibles.append({"kind": "shroom", "x": 9 * TILE + TILE // 2, "y": 6 * TILE - 22})
collectibles.append({"kind": "shroom_2", "x": 10 * TILE + TILE // 2, "y": 6 * TILE - 22})
collectibles.append({"kind": "crate", "x": 23 * TILE + TILE // 2, "y": 6 * TILE - 26})
collectibles.append({"kind": "shroom", "x": 24 * TILE + TILE // 2, "y": 6 * TILE - 22})
collectibles.append({"kind": "shroom_2", "x": 19 * TILE + TILE // 2, "y": GROUND_Y - 22})
on_ground(15, "crate")
on_ground(30, "shroom")

layout = {
    "tile_size": TILE,
    "cols": COLS,
    "rows": ROWS,
    "ground_y": GROUND_Y,
    "tiles": tiles,
    "decor": decor,
    "collectibles": collectibles,
    # stays on the (13..17) ground slab so it cannot walk into a gap
    "enemy": {"x": 900, "y": GROUND_Y, "left": 860, "right": 1120},
    "player_start": {"x": 110, "y": GROUND_Y - 90},
    "camera": {"min_x": 500, "max_x": 1500},
}

with open(os.path.join(ROOT, "levels", "level_layout.json"), "w") as f:
    json.dump(layout, f, indent=1)
print(f"levels/level_layout.json: {len(tiles)} tiles, {len(collectibles)} collectibles")

# ---------------------------------------------------------------- preview ----
ASSETS = os.path.join(ROOT, "assets")
TILE_FILES = {
    "grass_top_left": (0, 0), "grass_top": (1, 0), "grass_top_right": (2, 0),
    "dirt": (3, 0), "dirt_left": (4, 0), "dirt_right": (5, 0),
    "dirt_bottom_left": (0, 1), "dirt_bottom": (1, 1), "dirt_bottom_right": (2, 1),
}
atlas = Image.open(os.path.join(ASSETS, "tileset.png")).convert("RGBA")
bg = Image.open(os.path.join(ASSETS, "background.png")).convert("RGBA")
W, H = COLS * TILE, ROWS * TILE

scene = Image.new("RGBA", (W, H), (166, 219, 240, 255))
scene.alpha_composite(bg.resize((W, 750), Image.LANCZOS), (0, 0))

for t in tiles:
    sx, sy = TILE_FILES[t["tile"]]
    cell = atlas.crop((sx * TILE, sy * TILE, sx * TILE + TILE, sy * TILE + TILE))
    scene.alpha_composite(cell, (t["x"] * TILE, t["y"] * TILE))

for d in decor:
    im = Image.open(os.path.join(ASSETS, d["texture"] + ".png")).convert("RGBA")
    scene.alpha_composite(im, (d["x"] - im.width // 2, d["y"] - im.height))

for c in collectibles:
    im = Image.open(os.path.join(ASSETS, c["kind"] + ".png")).convert("RGBA")
    scene.alpha_composite(im, (c["x"] - im.width // 2, c["y"] - im.height // 2))

enemy = Image.open(os.path.join(ASSETS, "enemy.png")).convert("RGBA").crop((0, 0, 81, 49))
e = layout["enemy"]
scene.alpha_composite(enemy, (e["x"] - enemy.width // 2, e["y"] - enemy.height))

dino = Image.open(os.path.join(ASSETS, "dino_run.png")).convert("RGBA").crop((0, 0, 128, 128))
dino = dino.resize((int(128 * 0.78), int(128 * 0.78)), Image.LANCZOS)
scene.alpha_composite(dino, (layout["player_start"]["x"] - dino.width // 2,
                             layout["player_start"]["y"] + 30 - dino.height))

scene.save(os.path.join(ROOT, "artifacts", "level_preview.png"))
# a second image cropped to the first viewport, so detail is visible
scene.crop((0, 0, 1000, 700)).save(os.path.join(ROOT, "artifacts", "level_viewport.png"))
print("preview written", scene.size)
