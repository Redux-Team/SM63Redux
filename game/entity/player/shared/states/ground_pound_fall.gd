extends PlayerState


func _enter() -> void:
	player.velocity.y = player.ground_pound_fall_speed


func _tick(_delta: float) -> void:
	if player.velocity.y <= player.ground_pound_water_swim_speed and player.is_in_water():
		machine.change_state(&"SwimIdle")
	if player.is_in_water():
		player.velocity.y = lerpf(player.velocity.y, 0, player.ground_pound_water_slow_lerp)
	
	player.velocity.y = min(player.velocity.y, player.ground_pound_fall_speed)


func _next() -> StringName:
	return &"GroundPoundSlam" if player.is_on_floor() else &""
