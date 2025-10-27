extends StateProcess


func _on_water_check_area_entered(area: Area2D) -> void:
	if area.collision_layer & (1 << (3 - 1)):
		player.is_in_water = true
		player.current_jump = 0
		if not state_machine.current_state.name.contains("GroundPound"):
			state_machine.change_state(&"SwimIdle")
			player.velocity.y = max(player.velocity.y, player.velocity.y / 2)
		player.gravity_scale_factor = 0.2


func _on_water_check_area_exited(area: Area2D) -> void:
	if state_machine.current_state.name.contains("GroundPound"):
		return
	
	if area.collision_layer & (1 << (3 - 1)):
		player.is_in_water = false
		if player.is_on_floor():
			state_machine.change_state(&"Idle")
		else:
			state_machine.change_state_silent(&"Jump")
		player.gravity_scale_factor = 1.0
	if player.velocity.y < 0:
		player.velocity.y *= 1.325
