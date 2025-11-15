extends State

func _on_enter(_from: StringName) -> void:
	player.velocity.y = 800


func _physics_process(delta: float) -> void:
	if player.velocity.y <= 50 and player.is_in_water:
		state_machine.change_state(&"SwimIdle")
	if player.is_in_water:
		player.velocity.y = lerpf(player.velocity.y, 0, 0.08)


func _on_exit(_to: StringName) -> void:
	player.has_gravity = true
