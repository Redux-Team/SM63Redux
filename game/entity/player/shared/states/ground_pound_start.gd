extends PlayerState


func _enter() -> void:
	player.velocity.y = player.ground_pound_start_rise_speed
	player.velocity.x = 0
	player.jump_chain_index = 0


func _tick(_delta: float) -> void:
	player.velocity.y = player.ground_pound_start_rise_speed


func _next() -> StringName:
	return &"GroundPoundFall" if time >= player.ground_pound_start_duration else &""
