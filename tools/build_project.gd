extends SceneTree
## Generates the Godot resources for the platformer lab:
##   * project settings (window size, gravity, input map, layer names)
##   * assets/tileset.tres   - atlas TileSet with a physics layer
##   * level.tscn            - the TileMap painted from level_layout.json
##   * player.tscn           - CharacterBody2D with the animated dino
##   * shroom.tscn           - collectible pickup
##   * enemy.tscn            - patrolling enemy
##   * main.tscn             - background, level, player, camera/HUD, props
##
## Run with:  godot --headless --path . --script tools/build_project.gd

const TILE := 64
const CELL := 128
const ENEMY_CELL := Vector2i(81, 49)

# atlas grid written by tools/build_assets.py -> assets/tileset.png
const ATLAS := {
	"grass_top_left": Vector2i(0, 0),
	"grass_top": Vector2i(1, 0),
	"grass_top_right": Vector2i(2, 0),
	"dirt": Vector2i(3, 0),
	"dirt_left": Vector2i(4, 0),
	"dirt_right": Vector2i(5, 0),
	"dirt_bottom_left": Vector2i(0, 1),
	"dirt_bottom": Vector2i(1, 1),
	"dirt_bottom_right": Vector2i(2, 1),
}

var layout: Dictionary


func _initialize() -> void:
	layout = _read_json("res://level_layout.json")

	_setup_project_settings()
	_build_tileset()
	_build_player()
	_build_collectible()
	_build_enemy()
	_build_main()

	print("build done")
	quit()


# ------------------------------------------------------------------ helpers --
func _read_json(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		push_error("cannot open " + path)
		quit(1)
		return {}
	return JSON.parse_string(f.get_as_text())


func _add(parent: Node, child: Node) -> Node:
	parent.add_child(child)
	child.owner = parent
	return child


func _own_all(root: Node, node: Node) -> void:
	# every node of a scene has to be owned by the scene root to be saved;
	# instanced sub-scenes keep their own internal owners
	for child in node.get_children():
		child.owner = root
		if child.scene_file_path == "":
			_own_all(root, child)


func _save(node: Node, path: String) -> void:
	_own_all(node, node)
	var packed := PackedScene.new()
	var err := packed.pack(node)
	if err != OK:
		push_error("pack failed for " + path)
	err = ResourceSaver.save(packed, path)
	if err != OK:
		push_error("save failed for " + path)
	print("  saved ", path)


# ---------------------------------------------------------------- settings --
func _setup_project_settings() -> void:
	ProjectSettings.set_setting("application/config/name", "platformer")
	ProjectSettings.set_setting("display/window/size/viewport_width", 1000)
	ProjectSettings.set_setting("display/window/size/viewport_height", 700)
	ProjectSettings.set_setting("display/window/stretch/mode", "canvas_items")
	ProjectSettings.set_setting("physics/2d/default_gravity", 2000.0)
	ProjectSettings.set_setting("layer_names/2d_physics/layer_1", "world")
	ProjectSettings.set_setting("layer_names/2d_physics/layer_2", "player")
	ProjectSettings.set_setting("layer_names/2d_physics/layer_3", "collectible")
	ProjectSettings.set_setting("layer_names/2d_physics/layer_4", "enemy")

	_add_action("left", [KEY_LEFT, KEY_A])
	_add_action("right", [KEY_RIGHT, KEY_D])
	_add_action("jump", [KEY_SPACE, KEY_UP, KEY_W])
	ProjectSettings.save()
	print("settings written")


func _add_action(action: String, keys: Array) -> void:
	var events := []
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		events.append(ev)
	ProjectSettings.set_setting("input/" + action,
		{"deadzone": 0.5, "events": events})


# ----------------------------------------------------------------- tileset --
func _build_tileset() -> TileSet:
	var texture: Texture2D = load("res://assets/tileset.png")
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)   # "world"

	var src := TileSetAtlasSource.new()
	src.texture = texture
	src.texture_region_size = Vector2i(TILE, TILE)

	# the source has to be part of the TileSet before tile data can carry
	# collision polygons, otherwise the physics layer is unknown to it
	ts.add_source(src, 0)

	var corners := PackedVector2Array([
		Vector2(-TILE / 2.0, -TILE / 2.0), Vector2(TILE / 2.0, -TILE / 2.0),
		Vector2(TILE / 2.0, TILE / 2.0), Vector2(-TILE / 2.0, TILE / 2.0),
	])
	for name in ATLAS:
		var coords: Vector2i = ATLAS[name]
		src.create_tile(coords)
		var td := src.get_tile_data(coords, 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, corners)

	ResourceSaver.save(ts, "res://assets/tileset.tres")
	print("tileset: ", ATLAS.size(), " tiles")
	return ts


# ------------------------------------------------------------------- level --
func _paint_level(tm: TileMap) -> void:
	tm.tile_set = load("res://assets/tileset.tres")
	for cell in layout["tiles"]:
		var name: String = cell["tile"]
		if not ATLAS.has(name):
			push_warning("unknown tile " + name)
			continue
		tm.set_cell(0, Vector2i(cell["x"], cell["y"]), 0, ATLAS[name])


# ------------------------------------------------------------------ player --
func _make_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()   # comes with a "default" animation
	frames.add_animation("running")
	frames.add_animation("jumping")
	frames.set_animation_speed("default", 4.0)
	frames.set_animation_loop("default", true)
	frames.set_animation_speed("running", 16.0)
	frames.set_animation_loop("running", true)
	frames.set_animation_speed("jumping", 8.0)
	frames.set_animation_loop("jumping", false)
	_add_frames(frames, "default", "res://assets/dino_idle.png", 2)
	_add_frames(frames, "running", "res://assets/dino_run.png", 12)
	_add_frames(frames, "jumping", "res://assets/dino_jump.png", 3)
	return frames


func _add_frames(frames: SpriteFrames, anim: String, path: String, count: int) -> void:
	var tex: Texture2D = load(path)
	for i in count:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * CELL, 0, CELL, CELL)
		frames.add_frame(anim, at)


func _build_player() -> void:
	var body := CharacterBody2D.new()
	body.name = "Player"
	body.set_script(load("res://player.gd"))
	body.collision_layer = 2       # player
	body.collision_mask = 5        # world + collectibles
	body.floor_snap_length = 4.0
	body.add_to_group("player")

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite2D"
	sprite.sprite_frames = _make_frames()
	sprite.animation = "default"
	sprite.scale = Vector2(0.8, 0.8)
	sprite.offset = Vector2(0, -CELL * 0.8 * 0.5)   # feet on the origin
	_add(body, sprite)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(46, 80)
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	col.shape = shape
	col.position = Vector2(0, -40)
	_add(body, col)

	_save(body, "res://player.tscn")


# ------------------------------------------------------------ collectibles --
func _build_collectible() -> void:
	var body := StaticBody2D.new()
	body.name = "shroom"
	body.set_script(load("res://collectible.gd"))
	body.collision_layer = 4      # collectible
	body.collision_mask = 0
	body.add_to_group("collectible")

	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load("res://assets/shroom.png")
	_add(body, sprite)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(38, 38)
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	col.shape = shape
	_add(body, col)

	_save(body, "res://shroom.tscn")


# ------------------------------------------------------------------- enemy --
func _build_enemy() -> void:
	var body := CharacterBody2D.new()
	body.name = "Enemy"
	body.set_script(load("res://enemy.gd"))
	body.collision_layer = 8      # enemy
	body.collision_mask = 1      # world

	var tex: Texture2D = load("res://assets/enemy.png")
	var frames := SpriteFrames.new()
	frames.set_animation_speed("default", 3.0)
	for i in 2:
		var at := AtlasTexture.new()
		at.atlas = tex
		at.region = Rect2(i * ENEMY_CELL.x, 0, ENEMY_CELL.x, ENEMY_CELL.y)
		frames.add_frame("default", at)

	var sprite := AnimatedSprite2D.new()
	sprite.name = "Sprite2D"
	sprite.sprite_frames = frames
	sprite.animation = "default"
	sprite.scale = Vector2(1.4, 1.4)
	sprite.offset = Vector2(0, -ENEMY_CELL.y * 1.4 * 0.5)
	_add(body, sprite)

	var shape := RectangleShape2D.new()
	shape.size = Vector2(76, 56)
	var col := CollisionShape2D.new()
	col.name = "CollisionShape2D"
	col.shape = shape
	col.position = Vector2(0, -28)
	_add(body, col)

	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	hitbox.collision_layer = 0
	hitbox.collision_mask = 2      # player
	var hshape := RectangleShape2D.new()
	hshape.size = Vector2(80, 60)
	var hcol := CollisionShape2D.new()
	hcol.name = "CollisionShape2D"
	hcol.shape = hshape
	hcol.position = Vector2(0, -30)
	_add(hitbox, hcol)
	_add(body, hitbox)

	_save(body, "res://enemy.tscn")


# -------------------------------------------------------------------- main --
func _build_main() -> void:
	var root := Node2D.new()
	root.name = "Root"

	# a. Background -------------------------------------------------------
	var bg := TextureRect.new()
	bg.name = "Background"
	bg.texture = load("res://assets/background.png")
	bg.position = Vector2.ZERO
	bg.size = Vector2(layout["cols"] * TILE, 750)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_add(root, bg)

	# b. TileMap ----------------------------------------------------------
	var level := TileMap.new()
	level.name = "TileMap"
	_paint_level(level)
	_add(root, level)

	# decorations ---------------------------------------------------------
	var decor := Node2D.new()
	decor.name = "Decor"
	for d in layout["decor"]:
		var tex: Texture2D = load("res://assets/%s.png" % d["texture"])
		var s := Sprite2D.new()
		s.name = String(d["texture"]).replace("obj_", "")
		s.texture = tex
		s.centered = false
		s.position = Vector2(d["x"] - tex.get_width() * 0.5, d["y"] - tex.get_height())
		_add(decor, s)
	_add(root, decor)

	# collectibles --------------------------------------------------------
	var picks := Node2D.new()
	picks.name = "Collectibles"
	var i := 0
	for c in layout["collectibles"]:
		var inst: Node = load("res://shroom.tscn").instantiate()
		inst.name = "shroom%d" % i
		inst.position = Vector2(c["x"], c["y"])
		inst.set("item_texture", load("res://assets/%s.png" % c["kind"]))
		_add(picks, inst)
		i += 1
	_add(root, picks)

	# c. Player -----------------------------------------------------------
	var player: Node = load("res://player.tscn").instantiate()
	player.name = "Player"
	player.position = Vector2(layout["player_start"]["x"], layout["player_start"]["y"])
	_add(root, player)

	# h. Camera + HUD -----------------------------------------------------
	var cam := Camera2D.new()
	cam.name = "Camera2D"
	cam.set_script(load("res://camera.gd"))
	cam.position = Vector2(500, 350)
	cam.set("min_x", float(layout["camera"]["min_x"]))
	cam.set("max_x", float(layout["camera"]["max_x"]))
	_add(root, cam)

	var label := Label.new()
	label.name = "CollectedLabel"
	label.text = "Collected: 0 / %d" % layout["collectibles"].size()
	label.position = Vector2(26, 18)
	label.add_theme_font_size_override("font_size", 28)
	label.add_theme_color_override("font_color", Color(0.11, 0.1, 0.13))
	label.add_theme_color_override("font_outline_color", Color(1, 1, 1, 0.95))
	label.add_theme_constant_override("outline_size", 8)
	_add(cam, label)

	var button := Button.new()
	button.name = "ResetButton"
	button.text = "Reset"
	button.position = Vector2(858, 16)
	button.size = Vector2(116, 46)
	button.add_theme_font_size_override("font_size", 22)
	button.pressed.connect(Callable(cam, "_on_reset_button_pressed"),
		Object.CONNECT_PERSIST)
	_add(cam, button)

	# d. Enemy ------------------------------------------------------------
	var enemy: Node = load("res://enemy.tscn").instantiate()
	enemy.name = "Enemy"
	enemy.position = Vector2(layout["enemy"]["x"], layout["enemy"]["y"])
	enemy.set("left_x", float(layout["enemy"]["left"]))
	enemy.set("right_x", float(layout["enemy"]["right"]))
	_add(root, enemy)

	_save(root, "res://main.tscn")
