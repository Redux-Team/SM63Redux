extends State


func _on_enter(_from: StringName) -> void:
	player.set_gravity_scale_factor(0.67)
	player.is_spinning = true
	player.current_jump = 0
	player.jump_chain_timer = 0
	player.spin_area.set_deferred(&"monitoring", true)
	player.spin_area.set_deferred(&"monitorable", true)
	player.spin_shape.set_deferred(&"disabled", false)
	
	if not player.is_on_floor():
		player.set_gravity_enabled(false)
		if player.velocity.y > 0:
			player.velocity.y = -35
		else:
			player.velocity.y -= 50
		await get_tree().create_timer(0.1).timeout
		if is_active():
			player.set_gravity_enabled(true)
	
	await get_tree().create_timer(0.5).timeout
	if is_active():
		player.is_spinning = false


func _physics_process(_delta: float) -> void:
	if player._movement_locked:
		return
	
	if player.is_on_floor():
		player.lock_flipping = false
	
	player.velocity.y = min(player.velocity.y, 270)


func _on_exit(_to: StringName) -> void:
	player.set_gravity_enabled(true)
	player.set_gravity_scale_factor(1.0)
	
	player.spin_area.set_deferred(&"monitoring", false)
	player.spin_area.set_deferred(&"monitorable", false)
	player.spin_shape.set_deferred(&"disabled", true)
