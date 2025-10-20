extends State

func _on_enter(_from: StringName) -> void:
	player.velocity.x = clamp(player.velocity.x, -625, 625)
	player.velocity.y = -200
