extends PlayerState


func _enter() -> void:
	player.lock_flipping = true
	player.velocity.x += 280 * (int(player.sprite.flip_h) * 2 - 1)
	player.velocity.y = -400


func unlock_flipping() -> void:
	player.lock_flipping = false


func _exit() -> void:
	player.lock_flipping = false


func _next() -> StringName:
	if player.is_on_floor():
		return &"Idle"
	if player.is_action_just_pressed("dive"):
		return &"Dive"
	if player.is_input_spin and player.velocity.y > 155.0:
		return &"Spin"
	return &""
