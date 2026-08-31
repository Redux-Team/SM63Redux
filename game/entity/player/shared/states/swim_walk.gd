extends PlayerState


func _next() -> StringName:
	if player.is_input_swim:
		return &"Swim"
	if player.is_input_spin:
		return &"SwimSpin"
	return &""
