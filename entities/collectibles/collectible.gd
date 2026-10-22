extends StaticBody2D
## A pickup. Instances are named shroom0, shroom1, ... and carry the
## "collectible" group so the player can find them.

@export var item_texture: Texture2D

@onready var sprite: Sprite2D = $Sprite2D


func _ready() -> void:
	add_to_group("collectible")
	if item_texture:
		sprite.texture = item_texture
