#!/usr/bin/env python3
"""Build the Godot-ready art from the original downloaded sources.

Sources (see CREDITS.md):
  _downloads/pack/png/Tiles/*.png   pzUH "Free Platformer Game Tileset" (CC0)
  _downloads/pack/png/Object/*.png  same pack
  _downloads/pack/png/BG/BG.png     same pack
  _downloads/dino.gif               u/BlazetheBean walk cycle (used for the player)

Outputs into assets/:
  tileset.png       6x2 atlas of 64x64 tiles
  background.png    1000x750 scrolling background
  dino_idle.png     2-frame strip, 128x128 cells
  dino_run.png      12-frame strip, 128x128 cells
  dino_jump.png     3-frame strip, 128x128 cells
  enemy.png         enemy strip (stone + mushroom colours, 2 frames)
  obj_*.png         decorations downscaled 50%
"""

import os
import numpy as np
from PIL import Image, ImageSequence, ImageFilter
from scipy import ndimage

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PACK = os.path.join(ROOT, "_downloads", "pack", "png")
OUT = os.path.join(ROOT, "assets")
TILE = 64
CELL = 128

os.makedirs(OUT, exist_ok=True)


def resized(path, size, sharpen=True):
    im = Image.open(path).convert("RGBA")
    if im.size != (size, size):
        im = im.resize((size, size), Image.LANCZOS)
        if sharpen:
            im = im.filter(ImageFilter.UnsharpMask(radius=1.0, percent=60, threshold=0))
    return im


# ---------------------------------------------------------------- tileset ----
# Slot order is the atlas grid used by the TileSet in main.tscn.
TILE_ATLAS = [
    ("grass_top_left", 1), ("grass_top", 2), ("grass_top_right", 3),
    ("dirt", 5), ("dirt_left", 4), ("dirt_right", 6),
    ("dirt_bottom_left", 16), ("dirt_bottom", 9), ("dirt_bottom_right", 12),
]
COLS = 6
atlas = Image.new("RGBA", (COLS * TILE, 2 * TILE), (0, 0, 0, 0))
for i, (_, n) in enumerate(TILE_ATLAS):
    t = resized(os.path.join(PACK, "Tiles", f"{n}.png"), TILE)
    atlas.alpha_composite(t, ((i % COLS) * TILE, (i // COLS) * TILE))
atlas.save(os.path.join(OUT, "tileset.png"))
print("tileset.png", atlas.size)

# ------------------------------------------------------------- background ----
bg = Image.open(os.path.join(PACK, "BG", "BG.png")).convert("RGBA")
bg.save(os.path.join(OUT, "background.png"))
print("background.png", bg.size)

# ---------------------------------------------------------------- objects ----
for src, name in [
    ("Tree_2.png", "obj_tree"), ("Tree_3.png", "obj_tree_2"),
    ("Tree_1.png", "obj_stump"), ("Bush (1).png", "obj_bush"),
    ("Bush (3).png", "obj_bush_small"), ("Sign_1.png", "obj_sign"),
    ("Stone.png", "obj_stone"),
]:
    im = Image.open(os.path.join(PACK, "Object", src)).convert("RGBA")
    im = im.resize((max(1, im.width // 2), max(1, im.height // 2)), Image.LANCZOS)
    im.save(os.path.join(OUT, f"{name}.png"))
print("objects done")

# Collectibles keep native size (they are small already).
for src, name in [("Mushroom_1.png", "shroom"), ("Mushroom_2.png", "shroom_2"),
                  ("Crate.png", "crate")]:
    Image.open(os.path.join(PACK, "Object", src)).convert("RGBA").save(
        os.path.join(OUT, f"{name}.png"))

# ------------------------------------------------------------------- dino ----
gif = Image.open(os.path.join(ROOT, "_downloads", "dino.gif"))
raw = [f.convert("RGB").copy() for f in ImageSequence.Iterator(gif)]
print("gif frames", len(raw), raw[0].size)


def background_like(rgb):
    a = np.asarray(rgb).astype(np.int16)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    mx, mn = a.max(axis=2), a.min(axis=2)
    sat = mx - mn
    pale = (mx >= 150) & (sat <= 70)
    pale_green = (g > r + 15) & (g >= 150) & (b < g) & (sat <= 110)
    return pale | pale_green


def key_frame(rgb):
    """Drop the painted sky/grass, keep only the character."""
    mask = background_like(rgb)
    # only regions connected to the border are background; the pale belly,
    # horn and eye whites are enclosed by dark outlines and survive.
    lab, n = ndimage.label(mask)
    border = set(lab[0, :]) | set(lab[-1, :]) | set(lab[:, 0]) | set(lab[:, -1])
    border.discard(0)
    bg_only = np.isin(lab, list(border))
    alpha = np.where(bg_only, 0, 255).astype(np.uint8)
    # soften the cut edge so the sprite does not look die-cut
    soft = ndimage.uniform_filter(alpha.astype(np.float32), size=3)
    alpha = np.clip(soft, 0, 255).astype(np.uint8)
    rgba = np.dstack([np.asarray(rgb), alpha])
    return Image.fromarray(rgba, "RGBA")


keyed = [key_frame(f) for f in raw]

# one common crop box keeps every frame registered to the same canvas
box = None
for im in keyed:
    b = im.getbbox()
    box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]),
                                 max(box[2], b[2]), max(box[3], b[3]))
# pad a little for the spiky back and the tail
pad = 12
box = (max(0, box[0] - pad), max(0, box[1] - pad),
       min(keyed[0].width, box[2] + pad), min(keyed[0].height, box[3] + pad))
print("crop box", box, "size", box[2] - box[0], box[3] - box[1])


def to_cell(im, size=CELL):
    """Crop to the shared box, then fit inside a square cell, feet centred."""
    crop = im.crop(box)
    scale = min(size / crop.width, size / crop.height)
    w, h = max(1, round(crop.width * scale)), max(1, round(crop.height * scale))
    crop = crop.resize((w, h), Image.LANCZOS)
    cell = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    cell.alpha_composite(crop, ((size - w) // 2, size - h))  # bottom aligned
    return cell


cells = [to_cell(im) for im in keyed]

IDLE = [3, 8]                 # both feet together, breathing pose
RUN = list(range(len(cells)))  # the whole 12 frame cycle
JUMP = [2, 3, 4]              # tuck / extended poses, as the manual asks


def strip(indices, path):
    out = Image.new("RGBA", (CELL * len(indices), CELL), (0, 0, 0, 0))
    for i, idx in enumerate(indices):
        out.alpha_composite(cells[idx], (i * CELL, 0))
    out.save(os.path.join(OUT, path))
    print(path, out.size)


strip(IDLE, "dino_idle.png")
strip(RUN, "dino_run.png")
strip(JUMP, "dino_jump.png")

# ------------------------------------------------------------------ enemy ----
# A stone golem-ish enemy built from the pack's stone so it matches the art.
stone = Image.open(os.path.join(PACK, "Object", "Stone.png")).convert("RGBA")
enemy_rows = []
for squeeze in (1.0, 0.86):
    im = stone.resize((max(1, round(stone.width * 0.9)),
                       max(1, round(stone.height * 0.9 * squeeze))), Image.LANCZOS)
    enemy_rows.append(im)
ew = max(i.width for i in enemy_rows)
eh = max(i.height for i in enemy_rows)
enemy = Image.new("RGBA", (ew * 2, eh), (0, 0, 0, 0))
for i, im in enumerate(enemy_rows):
    enemy.alpha_composite(im, (i * ew + (ew - im.width) // 2, eh - im.height))
enemy.save(os.path.join(OUT, "enemy.png"))
print("enemy.png", enemy.size)

# a compact check sheet so the results can be eyeballed
check = Image.new("RGBA", (CELL * 6, CELL * 3), (255, 255, 255, 255))
for i, c in enumerate(cells[:12]):
    check.alpha_composite(c, ((i % 6) * CELL, (i // 6) * CELL))
check.save(os.path.join(ROOT, "artifacts", "dino_keyed.png"))
print("done")
