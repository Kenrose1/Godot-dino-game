extends CharacterBody2D
## Player character.
##
## Runs with acceleration, jumps, flips the sprite towards the direction of
## travel, plays the idle/running/jumping animations and picks up the
## collectibles it touches (the bodies named shroom0, shroom1, ...).

const SPEED := 280.0
const JUMP_VELOCITY := -820.0
const ACCELERATION := 2200.0
const FRICTION := 2600.0
const KILL_Y := 900.0

var collected := 0
var total := 0

@onready var sprite_2d: AnimatedSprite2D = $Sprite2D
@onready var collected_label: Label = get_node_or_null("../Camera2D/CollectedLabel")


func _ready() -> void:
	total = get_tree().get_nodes_in_group("collectible").size()
	_update_label()


func _physics_process(delta: float) -> void:
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 1600.0)
	if not is_on_floor():
		velocity.y += gravity * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	var direction := Input.get_axis("left", "right")
	if direction != 0.0:
		velocity.x = move_toward(velocity.x, direction * SPEED, ACCELERATION * delta)
	else:
		velocity.x = move_toward(velocity.x, 0.0, FRICTION * delta)

	move_and_slide()

	# a reference to the sprite lets us flip it and swap animations
	sprite_2d.flip_h = velocity.x < 0.0
	if not is_on_floor():
		sprite_2d.animation = "jumping"
	elif absf(velocity.x) > 12.0:
		sprite_2d.animation = "running"
	else:
		sprite_2d.animation = "default"

	# collect whatever we bumped into this frame
	for i in get_slide_collision_count():
		var collider := get_slide_collision(i).get_collider()
		if collider and collider.is_in_group("collectible"):
			collider.queue_free()
			collected += 1
			_update_label()

	if global_position.y > KILL_Y:
		get_tree().reload_current_scene()


func _update_label() -> void:
	if collected_label:
		collected_label.text = "Collected: %d / %d" % [collected, total]
