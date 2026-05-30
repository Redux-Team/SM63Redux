@tool
extends State

@export var spin_hitbox: HitBox


func _on_enter() -> void:
	player.set_gravity_scale_factor(0.67)
	player.is_spinning = true
	player.jump_chain_timer = 0
	spin_hitbox.enable(0.3)
	
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


func _on_physics_tick(_delta: float) -> void:
	if player.is_on_floor():
		player.lock_flipping = false
	
	player.velocity.y = min(player.velocity.y, 270)


func _on_exit() -> void:
	player.set_gravity_enabled(true)
	player.set_gravity_scale_factor(1.0)
	spin_hitbox.disable()
