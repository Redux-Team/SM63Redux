extends State

func _on_enter(_from: StringName) -> void:
	player.velocity.x = clamp(player.velocity.x, -625, 625)
	player.velocity.y = -200
	player.can_dive = false
	await pause(0.275)
	player.can_dive = true


func _on_exit(_to: StringName) -> void:
	player.can_dive = true
