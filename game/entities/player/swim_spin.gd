extends State


func _on_enter(_from: StringName) -> void:
	if not player.is_on_floor():
		if player.velocity.y > 0:
			player.velocity.y = -35
		else:
			player.velocity.y -= 50


func _physics_process(_delta: float) -> void:
	if player.is_on_floor():
		player.lock_flipping = false
	player.velocity.y = min(player.velocity.y, -3)
