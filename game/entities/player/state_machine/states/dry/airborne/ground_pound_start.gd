extends State

func _on_enter(_from: StringName) -> void:
	(player.get_component(GravityComponent) as GravityComponent).lock()
	player.velocity.y = -38
	player.velocity.x = 0
	player.current_jump = 0
