extends PlayerState


func _next() -> StringName:
	return &"Spin" if player.is_input_spin and player.velocity.y > player.jump_spin_min_speed else &""
