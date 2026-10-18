extends PlayerState


func _tick(delta: float) -> void:
	_tick_jump_chain(delta)
	if not player.is_on_floor() and controls.is_held(&"ground_pound") and player.can_ground_pound:
		machine.change_state(&"GroundPoundStart")


func _next() -> StringName:
	return &"SwimIdle" if player.is_swimming() else &""


func _tick_jump_chain(delta: float) -> void:
	if not player.is_on_floor() or not player.can_jump:
		return
	
	player.jump_chain_timer = maxf(player.jump_chain_timer - delta, 0.0)
	if player.jump_chain_timer <= 0.0:
		player.jump_chain = 0
