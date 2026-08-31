extends PlayerState


func _enter() -> void:
	player.velocity.y = player.gp_start_rise_speed
	player.velocity.x = 0
	player.current_jump = 0


func _tick(_delta: float) -> void:
	player.velocity.y = player.gp_start_rise_speed


func _next() -> StringName:
	return &"GroundPoundFall" if time >= player.gp_start_duration else &""
