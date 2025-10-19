extends State


func _on_enter(_from: StringName) -> void:
	player.is_diving = true
	player.lock_flipping = true
	
	if player.sprite.flip_h:
		player.velocity.x = -500
	else:
		player.velocity.x = 500
	player.velocity.y *= 0.5


func _on_exit(_to: StringName) -> void:
	player.is_diving = false
	player.lock_flipping = false
