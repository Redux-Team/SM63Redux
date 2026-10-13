extends PlayerState

@export var floor_friction_scale: float = 1.0
@export var idle_floor_friction_scale: float = 1.39


func _tick(delta: float) -> void:
	var control: PlayerAirControl = _get_control()
	var input: float = player.move_input
	var speed: float = player.velocity.x
	var max_speed: float = player.get_air_speed(control.max_speed)
	if is_zero_approx(input):
		speed = Motion.approach(speed, 0.0, control.over_speed_drag if absf(speed) > max_speed else control.drag, delta)
	elif absf(speed) < max_speed or signf(speed) != signf(input):
		var turning: bool = signf(speed) != signf(input) and absf(speed) > control.turn_speed_threshold
		speed = Motion.approach(speed, max_speed * input, control.turn_acceleration if turning else control.acceleration, delta)
	elif not player.fludd.is_spraying():
		speed = Motion.approach(speed, control.momentum_max_speed * signf(speed), control.momentum_acceleration, delta)
	
	if player.is_on_floor():
		var scale: float = idle_floor_friction_scale if is_zero_approx(input) else floor_friction_scale
		speed = Motion.drift(speed, 0.0, player.get_floor_drag_rate() * scale, delta)
	
	player.velocity.x = speed


func _get_control() -> PlayerAirControl:
	if player.is_on_floor():
		return air_control
	
	var node: Node = machine.get_state()
	while node != self:
		var state: PlayerState = node as PlayerState
		if state.air_control:
			return state.air_control
		node = node.get_parent()
	
	return air_control
