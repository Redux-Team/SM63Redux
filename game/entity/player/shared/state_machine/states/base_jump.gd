@tool
class_name BaseJump
extends State


func _pre_enter() -> void:
	if is_active():
		return
	var phase: int = player.current_jump + 1
	var strengths: Array[float] = [0.0, player.jump_strength, player.double_jump_strength, player.triple_jump_strength]
	var chain_times: Array[float] = [0.0, player.jump_chain_time, player.jump_chain_time, 0.0]
	player.velocity.y = -strengths[phase]
	player.jump_chain_timer = chain_times[phase]
	player.current_jump = phase
	player.can_jump = false


func _on_exit() -> void:
	player.can_jump = true
