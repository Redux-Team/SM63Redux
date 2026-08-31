class_name BaseJump
extends PlayerState


func _enter() -> void:
	var phase: int = player.current_jump + 1
	if phase == 3 and (abs(player.velocity.x) < 120 or not player.is_moving_with_facing()):
		phase = 2
	
	phase = min(phase, 3)
	
	var strengths: Array[float] = [0.0, player.jump_strength, player.double_jump_strength, player.triple_jump_strength]
	var chain_times: Array[float] = [0.0, player.jump_chain_time, player.jump_chain_time, 0.0]
	player.velocity.y = -strengths[phase]
	player.jump_chain_timer = chain_times[phase]
	player.current_jump = phase
	player.can_jump = false


func _exit() -> void:
	player.can_jump = true


func _next() -> StringName:
	if player.is_action_just_pressed("dive") and player.can_dive and time > 0.0:
		return &"Dive"
	if player.velocity.y >= 0.0 and not player.is_on_floor():
		return &"Fall"
	if player.is_on_floor() and not player.is_input_jump:
		return &"Idle"
	
	if is_current():
		match player.current_jump:
			1: return &"Jump"
			2: return &"DoubleJump"
			3: return &"TripleJump"
	return &""
