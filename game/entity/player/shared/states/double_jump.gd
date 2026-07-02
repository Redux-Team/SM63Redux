@tool
extends State


func _on_enter() -> void:
	player.velocity.y = -player.double_jump_strength
	player.jump_chain_timer = player.jump_chain_time
	
	await get_tree().physics_frame
	if not is_active():
		return
	player.current_jump += 1
