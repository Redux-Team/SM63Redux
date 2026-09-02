extends PlayerState


func _enter() -> void:
	player.lock_flipping = true
	player.velocity.x -= player.backflip_up_x_boost * player.get_facing()
	player.velocity.y = player.backflip_up_y_velocity


func unlock_flipping() -> void:
	player.lock_flipping = false


func _exit() -> void:
	player.lock_flipping = false


func _next() -> StringName:
	if player.is_on_floor():
		return &"Idle"
	if player.is_input_spin and player.velocity.y > player.backflip_spin_min_speed:
		return &"Spin"
	if player.is_action_just_pressed("dive") and player.can_dive:
		return &"Dive"
	return &""
