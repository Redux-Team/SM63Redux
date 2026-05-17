@tool
extends State

@export var fuse: SmartSprite2D
@export var key: SmartSprite2D


func _on_enter() -> void:
	fuse.hide()
	key.hide()
