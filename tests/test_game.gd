extends Node
## Headless behaviour tests for the platformer.
## Run with:
##   godot --headless --path . res://tests/test_game.tscn

var failures := 0
var passes := 0


func _ready() -> void:
	await get_tree().process_frame   # let the tree finish setting up
	var main := _load_main()
	await _test_layout(main)
	await _test_assets_and_hud(main)
	await _test_landing(main)
	await _test_jump(main)
	await _test_movement(main)
	await _test_camera(main)
	await _test_gap_jump(main)
	await _test_collectible(main)
	await _test_enemy(main)
	await _test_fall_restarts(main)

	print("")
	print("passed: %d   failed: %d" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _load_main() -> Node:
	var main: Node = load("res://main.tscn").instantiate()
	get_tree().root.add_child(main)
	get_tree().current_scene = main
	return main


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		passes += 1
		print("  PASS  ", what)
	else:
		failures += 1
		print("  FAIL  ", what)


# ------------------------------------------------------------------- tests --
func _test_layout(main: Node) -> void:
	print("layout")
	var tm: TileMap = main.get_node("TileMap")
	_check(tm.get_cell_source_id(0, Vector2i(0, 8)) != -1, "ground exists at column 0")
	_check(tm.get_cell_source_id(0, Vector2i(6, 8)) == -1, "there is a gap at column 6")
	_check(tm.get_cell_source_id(0, Vector2i(18, 8)) == -1, "the wide gap is open on the left")
	_check(tm.get_cell_source_id(0, Vector2i(19, 8)) != -1, "pillar island in the wide gap")
	_check(tm.get_cell_source_id(0, Vector2i(20, 8)) == -1, "the wide gap is open on the right")
	_check(tm.get_cell_source_id(0, Vector2i(9, 6)) != -1, "plateau above the ground")
	_check(main.get_node("Collectibles").get_child_count() == 7, "7 collectibles placed")
	_check(main.get_node("Player").total == 7, "player knows the collectible total")


func _test_assets_and_hud(main: Node) -> void:
	print("art and HUD")
	var frames: SpriteFrames = main.get_node("Player/Sprite2D").sprite_frames
	_check(frames.get_frame_count("default") == 2, "idle animation has 2 frames")
	_check(frames.get_frame_count("running") == 12, "running animation has 12 frames")
	_check(frames.get_frame_count("jumping") == 3, "jumping animation has 3 frames")
	var crate: Sprite2D = main.get_node("Collectibles/shroom2/Sprite2D")
	_check(crate.texture != null and crate.texture.get_size() == Vector2(77, 77),
		"each collectible shows its own art (crate is 77x77)")
	var label: Label = main.get_node("Camera2D/CollectedLabel")
	_check(label.text == "Collected: 0 / 7", "counter starts at zero (label='%s')" % label.text)
	var button: Button = main.get_node("Camera2D/ResetButton")
	_check(button.pressed.get_connections().size() > 0, "reset button is wired to the camera")


func _test_landing(main: Node) -> void:
	print("gravity and ground")
	var p: CharacterBody2D = main.get_node("Player")
	await _frames(90)
	_check(p.is_on_floor(), "player lands on the ground")
	_check(absf(p.position.y - 512.0) < 8.0, "player rests on the surface (y=%.1f)" % p.position.y)
	_check(absf(p.position.x - 110.0) < 2.0, "player does not slide while idle")


func _test_jump(main: Node) -> void:
	print("jump")
	var p: CharacterBody2D = main.get_node("Player")
	var sprite: AnimatedSprite2D = p.get_node("Sprite2D")
	Input.action_press("jump")
	await _frames(3)
	Input.action_release("jump")
	_check(p.velocity.y < -100.0, "jump pushes the player up (vy=%.1f)" % p.velocity.y)
	_check(sprite.animation == "jumping", "jump animation plays")
	await _frames(90)
	_check(p.is_on_floor(), "player comes back down")


func _test_movement(main: Node) -> void:
	print("movement")
	var p: CharacterBody2D = main.get_node("Player")
	var sprite: AnimatedSprite2D = p.get_node("Sprite2D")
	var start_x := p.position.x
	Input.action_press("right")
	await _frames(30)
	_check(p.position.x > start_x + 40.0, "holding right moves the player right")
	_check(sprite.animation == "running", "running animation plays")
	_check(sprite.flip_h == false, "sprite faces right")
	Input.action_release("right")

	Input.action_press("left")
	await _frames(25)
	Input.action_release("left")
	_check(sprite.flip_h == true, "sprite flips to face left")
	await _frames(40)
	_check(absf(p.velocity.x) < 5.0, "player stops when no key is held")


func _test_camera(main: Node) -> void:
	print("camera")
	var p: CharacterBody2D = main.get_node("Player")
	var cam: Camera2D = main.get_node("Camera2D")
	p.position = Vector2(900, 512)
	await _frames(60)
	_check(cam.position.x > 600.0, "camera follows to the right (x=%.1f)" % cam.position.x)

	p.position = Vector2(1900, 512)
	await _frames(90)
	_check(absf(cam.position.x - 1500.0) < 15.0, "camera stops at max_x (x=%.1f)" % cam.position.x)

	p.position = Vector2(150, 512)
	await _frames(120)
	_check(absf(cam.position.x - 500.0) < 15.0, "camera stops at min_x (x=%.1f)" % cam.position.x)


func _test_gap_jump(main: Node) -> void:
	print("jumping a gap")
	var p: CharacterBody2D = main.get_node("Player")
	p.position = Vector2(280, 512)
	p.velocity = Vector2.ZERO
	await _frames(5)
	Input.action_press("right")
	await _frames(15)          # build up running speed on flat ground
	Input.action_press("jump")
	await _frames(2)
	Input.action_release("jump")
	var landed := -1.0
	for i in 120:
		await get_tree().physics_frame
		if i > 5 and p.is_on_floor():
			landed = p.position.x
			break
	Input.action_release("right")
	_check(landed > 448.0 and landed < 705.0,
		"a running jump clears the first gap (landed at x=%.1f)" % landed)


func _test_collectible(main: Node) -> void:
	print("collectibles")
	var p: CharacterBody2D = main.get_node("Player")
	var label: Label = main.get_node("Camera2D/CollectedLabel")
	var shroom: Node2D = main.get_node("Collectibles/shroom0")
	p.position = shroom.position
	await _frames(8)
	_check(not is_instance_valid(shroom), "collectible disappears when touched")
	_check(label.text.begins_with("Collected: 1 /"), "counter increments (label='%s')" % label.text)


func _test_enemy(main: Node) -> void:
	print("enemy")
	var enemy: CharacterBody2D = main.get_node("Enemy")
	var hitbox: Area2D = enemy.get_node("Hitbox")
	var start_x := enemy.position.x
	_check(hitbox.body_entered.get_connections().size() > 0, "enemy hitbox is wired up")
	await _frames(90)
	_check(absf(enemy.position.x - start_x) > 20.0, "enemy patrols")
	_check(enemy.position.x > 800.0 and enemy.position.x < 1180.0,
		"enemy stays inside its patrol range (x=%.1f)" % enemy.position.x)
	_check(absf(enemy.position.y - 512.0) < 40.0, "enemy stays on the ground (y=%.1f)" % enemy.position.y)


func _test_fall_restarts(main: Node) -> void:
	print("falling into a gap")
	var p: CharacterBody2D = main.get_node("Player")
	p.position = Vector2(416, 300)   # straight down the first gap
	var restarted := false
	for i in 300:
		await get_tree().physics_frame
		if not is_instance_valid(p) or get_tree().current_scene != main:
			restarted = true
			break
	_check(restarted, "falling in a gap restarts the level")
	await _frames(10)
	var fresh := get_tree().current_scene
	_check(fresh != null and fresh.get_node_or_null("Player") != null, "level reloads with a player")
	if fresh and fresh.get_node_or_null("Player"):
		_check(fresh.get_node("Player").position.x < 200.0, "player respawns at the start")
