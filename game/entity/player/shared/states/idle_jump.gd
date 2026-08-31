extends PlayerState


func _next() -> StringName:
	if player.is_action_just_pressed("dive") and player.can_dive and time > 0.0:
		return &"Dive"
	if player.is_on_floor():
		return &"Idle"
	if player.velocity.y > player.idle_jump_fall_speed:
		return &"Fall"
	return &""
