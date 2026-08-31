extends PlayerState


func _next() -> StringName:
	if player.is_input_spin:
		return &"Spin"
	if player.is_action_pressed("crouch") and absf(player.velocity.x) <= 50.0 and player.is_on_floor():
		return &"Crouch"
	if player.is_action_just_pressed("crouch") and absf(player.velocity.x) > 50.0 and player.is_on_floor():
		return &"Floorslide"
	if absf(player.move_dir) > 0.1 and player.is_on_floor():
		return &"Walk"
	if player.velocity.y >= 0.0 and not player.is_on_floor():
		return &"Fall"
	if player.is_on_floor() and player.is_action_just_pressed("jump", 0.2) and player.can_jump:
		return &"BaseJump"
	return &""
