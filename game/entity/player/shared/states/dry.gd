@tool
extends State


func _on_physics_tick(_delta: float) -> void:
	if abs(player.move_dir) == 0 and not player.is_diving:
		var friction: FrictionComponent = player.get_component(FrictionComponent)
		friction.apply(0.4)
	
	player.is_falling = player.velocity.y > 0
	_handle_ground_pound()




func _handle_ground_pound() -> void:
	if not player.is_on_floor() and player.is_input_ground_pound:
		state_machine.change_state(&"GroundPoundStart")
