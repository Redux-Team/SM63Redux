extends PlayerState


func _next() -> StringName:
	if player.is_on_floor():
		return &"Idle"
	if player.is_input_spin and player.velocity.y > player.fall_spin_min_speed:
		return &"Spin"
	if player.is_action_just_pressed("dive") and player.can_dive:
		return &"Dive"
	return &""
