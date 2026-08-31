extends PlayerState


func _enter() -> void:
	var last: State = machine.get_last_state()
	if not last:
		return
	
	if last.name in [&"DoubleJump", &"TripleJump"]:
		sprite.play(&"double_jump_fall")
	elif last.name == &"Spin" or not _fell_from_air(last):
		sprite.play(&"fall_loop")


func _next() -> StringName:
	if player.is_on_floor():
		return &"Idle"
	if player.is_input_spin and player.velocity.y > player.fall_spin_min_speed:
		return &"Spin"
	if player.is_action_just_pressed("dive") and player.can_dive:
		return &"Dive"
	return &""


func _fell_from_air(state: State) -> bool:
	var node: Node = state
	while node is State:
		if node.name == &"Airborne":
			return true
		node = node.get_parent()
	
	return false
