@tool
extends State

@export var jump_strength: float = 400

func _on_enter() -> void:
	player.lock_flipping = true
	player.velocity.x += 280 * (int(player.sprite.flip_h) * 2 - 1)
	player.velocity.y = -jump_strength


func unlock_flipping() -> void:
	player.lock_flipping = false


func _on_exit() -> void:
	player.lock_flipping = false
