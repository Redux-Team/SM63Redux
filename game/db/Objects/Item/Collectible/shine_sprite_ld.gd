@tool
extends LDObjectSprite

@export var sprite: SmartSprite2D


func _ready() -> void:
	sprite.play(&"spin")
