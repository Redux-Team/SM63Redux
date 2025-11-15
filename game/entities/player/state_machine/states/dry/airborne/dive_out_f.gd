extends State

func _on_enter(_from: StringName) -> void:
	player.velocity.x = clamp(player.velocity.x, -625, 625)
	player.velocity.y = -200
	player.can_dive = false
	await get_tree().create_timer(0.2).timeout
	player.can_dive = true
