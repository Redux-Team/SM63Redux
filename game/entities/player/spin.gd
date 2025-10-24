extends State


func _on_enter(_from: StringName) -> void:
	player.gravity_scale_factor = 0.67
	player.is_spinning = true
	player.current_jump = 0
	player.jump_chain_timer = 0
	
	if not player.is_on_floor():
		player.has_gravity = false
		if player.velocity.y > 0:
			player.velocity.y = -35
		else:
			player.velocity.y -= 50
		await get_tree().create_timer(0.1).timeout
		player.has_gravity = true
	
	await get_tree().create_timer(0.5).timeout
	player.is_spinning = false


func _physics_process(_delta: float) -> void:
	player.velocity.y = min(player.velocity.y, 270)


func _on_exit(_to: StringName) -> void:
	player.gravity_scale_factor = 1.0
