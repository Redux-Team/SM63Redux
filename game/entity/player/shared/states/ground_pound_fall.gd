extends PlayerState


func _enter() -> void:
	player.velocity.y = 800


func _tick(_delta: float) -> void:
	if player.velocity.y <= 50 and player.is_in_water():
		machine.change_state(&"SwimIdle")
	if player.is_in_water():
		player.velocity.y = lerpf(player.velocity.y, 0, 0.08)
	
	player.velocity.y = min(player.velocity.y, 800)


func _next() -> StringName:
	return &"GroundPoundSlam" if player.is_on_floor() else &""
