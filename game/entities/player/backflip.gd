extends State


func _on_enter(_from: StringName) -> void:
	player.lock_flipping = true
	player.velocity.x += 350 * (int(player.sprite.flip_h) * 2 - 1)
	player.velocity.y = -430


func unlock_flipping() -> void:
	player.lock_flipping = false


func _on_exit(_to: StringName) -> void:
	player.lock_flipping = false
