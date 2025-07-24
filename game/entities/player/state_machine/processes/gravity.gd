extends StateProcess


func _physics_process(_delta: float) -> void:
	if player.disable_gravity:
		return
	
	if not player.is_on_floor() and player.terminal_velocity_y > player.velocity.y:
		player.velocity.y += player.gravity
