@tool
extends State

@export var jump_strength: float = 475
@export var backwards_speed: float = 50

func _on_enter() -> void:
	player.lock_flipping = true
	player.velocity.x += backwards_speed * (1 if player.sprite.flip_h else -1)
	player.velocity.y = -jump_strength


func unlock_flipping() -> void:
	player.lock_flipping = false


func _on_exit() -> void:
	player.lock_flipping = false
