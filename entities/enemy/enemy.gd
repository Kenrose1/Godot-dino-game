extends CharacterBody2D
## Patrolling enemy. Walks between left_x and right_x and reloads the level
## when it touches the player.

const GRAVITY := 2000.0

@export var left_x := 1030.0
@export var right_x := 1390.0
@export var speed := 70.0

var direction := -1.0

@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var hitbox: Area2D = $Hitbox


func _ready() -> void:
	if hitbox:
		hitbox.body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	velocity.y += GRAVITY * delta
	velocity.x = speed * direction
	move_and_slide()

	if position.x <= left_x:
		direction = 1.0
	elif position.x >= right_x:
		direction = -1.0
	elif is_on_wall():
		direction = -direction

	if sprite:
		sprite.flip_h = direction > 0.0


func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		get_tree().reload_current_scene()
