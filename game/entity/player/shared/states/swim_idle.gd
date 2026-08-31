extends PlayerState


func _next() -> StringName:
	if player.is_input_spin:
		return &"SwimSpin"
	if player.is_input_swim:
		return &"Swim"
	if absf(player.move_dir) > player.move_input_threshold and player.is_on_floor():
		return &"SwimWalk"
	return &""
