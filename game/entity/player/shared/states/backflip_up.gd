@tool
extends State


func _on_enter() -> void:
	player.lock_flipping = true
	player.velocity.x += 50 * (int(player.sprite.flip_h) * 2 - 1)
	player.velocity.y = -500


func unlock_flipping() -> void:
	player.lock_flipping = false


func _on_exit() -> void:
	player.lock_flipping = false
