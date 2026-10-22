extends Camera2D
## Follows the player inside a dead zone, clamped to the level bounds, and
## carries the HUD (collectible counter and reset button).

@export var min_x := 500.0
@export var max_x := 1500.0
@export var dead_zone := 120.0
@export var follow_speed := 6.0

@onready var player: CharacterBody2D = get_node_or_null("../Player")


func _process(delta: float) -> void:
	if player == null:
		return
	var target_x := position.x
	if player.position.x > position.x + dead_zone:
		target_x = player.position.x - dead_zone
	elif player.position.x < position.x - dead_zone:
		target_x = player.position.x + dead_zone
	target_x = clampf(target_x, min_x, max_x)
	position.x = lerpf(position.x, target_x, 1.0 - exp(-follow_speed * delta))


func _on_reset_button_pressed() -> void:
	get_tree().reload_current_scene()
