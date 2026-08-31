extends PlayerState


func _next() -> StringName:
	if player.is_input_spin:
		return &"SwimSpin"
	if player.is_input_swim:
		return &"Swim"
	if absf(player.move_dir) > 0.1 and player.is_on_floor():
		return &"SwimWalk"
	return &""
