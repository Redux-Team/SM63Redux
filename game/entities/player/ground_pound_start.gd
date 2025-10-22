extends State

func _on_enter(_from: StringName) -> void:
	player.has_gravity = false
	player.velocity.y = -38
	player.velocity.x = 0
