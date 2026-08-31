extends PlayerState


func _next() -> StringName:
	return &"Spin" if player.is_input_spin and player.velocity.y > -55.0 else &""
