class_name BaseJump
extends PlayerState

@export var jump_particles: AnimatedParticles

func _enter() -> void:
	var jump_index: int = player.jump_chain_index + 1
	if jump_index == 3 and (abs(player.velocity.x) < player.triple_jump_min_speed or not player.is_moving_with_facing()):
		jump_index = 2
	
	jump_particles.burst()
	jump_index = min(jump_index, 3)
	
	var jump_strengths: Array[float] = [0.0, player.jump_strength, player.double_jump_strength, player.triple_jump_strength]
	var jump_chain_times: Array[float] = [0.0, player.jump_chain_time, player.jump_chain_time, 0.0]
	player.velocity.y = -jump_strengths[jump_index]
	player.jump_chain_timer = jump_chain_times[jump_index]
	player.jump_chain_index = jump_index
	player.can_jump = false


func _exit() -> void:
	player.can_jump = true


func _next() -> StringName:
	if player.is_action_just_pressed("dive") and player.can_dive and time > 0.0:
		return &"Dive"
	if player.velocity.y > 0.0 and not player.is_on_floor():
		return &"Fall"
	if player.is_on_floor():
		return &"Idle"
	
	if is_current():
		match player.jump_chain_index:
			1: return &"Jump"
			2: return &"DoubleJump"
			3: return &"TripleJump"
	return &""
