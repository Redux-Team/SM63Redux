extends PlayerState


func _next() -> StringName:
	if player.is_action_just_pressed("jump"):
		if player.is_moving_against_facing():
			return &"Backflip"
		if is_zero_approx(player.move_input):
			return &"BackflipUp"
	if not player.is_crouching:
		return &"CrouchUp"
	return &""
