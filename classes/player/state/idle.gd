extends PlayerState


func tell_switch():
	if input.is_moving_x():
		return &"Walk"
	return &""
