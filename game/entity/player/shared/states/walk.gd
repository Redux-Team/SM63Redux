extends PlayerState


func _next() -> StringName:
	if not player.is_on_floor() and player.velocity.y >= 0.0:
		return &"Fall"
	if absf(player.move_dir) < 0.1 and absf(player.velocity.x) < 0.5:
		return &"Idle"
	if player.is_action_just_pressed("crouch") and player.is_on_floor():
		if absf(player.velocity.x) <= 50.0:
			return &"Crouch"
		if player.is_moving_with_facing():
			return &"Floorslide"
	if player.is_input_spin:
		return &"Spin"
	if player.is_on_floor() and player.is_action_just_pressed("jump", 0.2) and player.can_jump:
		return &"BaseJump"
	return &""
