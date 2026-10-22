# Platformer — Godot 4 platformer

A side-scrolling platformer built for the *Lab Activity #3 — Platformer Game
(Godot 4.x)* brief: tiles, animated sprites, collectibles, collisions, gaps and
a following camera.

## Running it

Open `project.godot` in **Godot 4.4** (any 4.x that reads `format=3` scenes
works) and press **F5**.

| Action | Keys |
| --- | --- |
| Move | `←` `→` or `A` `D` |
| Jump | `Space`, `↑` or `W` |
| Restart | **Reset** button, top right |

Collect the **7** pickups (mushrooms and crates), jump the four pits and dodge
the stone golem. Falling into a pit or touching the golem reloads the level.

## Scene layout

`levels/main.tscn`

```
Root (Node2D)
├── Background   TextureRect, 2048x750, stretched, scrolling backdrop
├── TileMap      level painted from 64px tiles (blank+grass, dirt, edges)
├── Decor        trees, bushes, stump, sign (no collision)
├── Collectibles shroom0 … shroom6 (StaticBody2D instances of
│                entities/collectibles/shroom.tscn)
├── Player       entities/player/player.tscn instance, started above the first slab
├── Camera2D     levels/camera.gd, holds the HUD
│   ├── CollectedLabel   "Collected: n / 7"
│   └── ResetButton      reloads the scene
└── Enemy        entities/enemy/enemy.tscn instance, patrols the middle slab
```

Other scenes: `entities/player/player.tscn` (CharacterBody2D + AnimatedSprite2D with the
`default` / `running` / `jumping` animations + collision shape),
`entities/collectibles/shroom.tscn`
(collectible), `entities/enemy/enemy.tscn` (patroller with a `Hitbox` area).

## Scripts

* **entities/player/player.gd** — gravity, acceleration/friction, jump, sprite flipping,
  animation switching, collectible pickup through `move_and_slide()`, and a
  restart if the dino falls below the world.
* **levels/camera.gd** — follows the player inside a 120px dead zone, both directions,
  clamped to `min_x` 500 / `max_x` 1500; the HUD is parented to it so it moves
  with the view.
* **entities/enemy/enemy.gd** — walks between `left_x` and `right_x`, turns at walls, reloads
  the level when its `Hitbox` touches the player.
* **entities/collectibles/collectible.gd** — applies its exported texture and joins the
  `collectible` group.

Physics use one "world" tile layer, a "player" layer, a "collectible" layer and
an "enemy" layer, so collectibles never block the patrolling enemy.

## The level

32 × 11 tiles of 64px — 2048 × 704px, twice the 1000 × 700 viewport, so the
camera pans as you travel.

* Ground slabs **0-5 · 7-10 · 13-17 · 21-25 · 28-31**
* Gaps at **6**, **11-12**, **18-20** (split by a one-tile pillar island) and
  **26-27**
* Two raised plateaus at **9-10** and **23-24** carrying the pickups
* Jump arc: `JUMP_VELOCITY -820`, gravity `2000`, `SPEED 280` → about 168px high
  and 230px far, which clears every gap with margin.

## Regenerating art and scenes

The art is derived from the original downloads in `_downloads/` (that folder is
`gdignore`d so Godot does not import it):

```bash
python3 tools/build_assets.py      # slices the tileset, keys the dino frames out of the GIF
python3 tools/build_level.py       # writes levels/level_layout.json + artifacts/level_preview.png
godot --headless --path . --import
godot --headless --path . --script tools/build_project.gd   # scenes, tileset.tres, project settings
```

`levels/level_layout.json` is the single source of truth for the level: the preview
image and the painted TileMap come from the same cells.

## Tests

38 headless checks (ground, gaps, jump, movement, sprite flip, animations,
camera clamping both ways, collectible pickup and counter, enemy patrol and
hitbox, falling into a pit restarting the level):

```bash
godot --headless --path . res://tests/test_game.tscn
```

A screenshot cannot be captured on a machine without a display server; run the
project from the editor to see it.
