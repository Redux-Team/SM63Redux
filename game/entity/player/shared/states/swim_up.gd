extends PlayerState


var _burst_timer: float = 0.0
var _burst_queued: bool = false


func _enter() -> void:
	_burst()


func _tick(delta: float) -> void:
	_burst_timer = max(_burst_timer - delta, 0.0)
	
	if player.is_input_swim:
		_burst_queued = true
		player.swim_input_timer = 0.0
	
	if _burst_queued and _burst_timer <= 0.0:
		_burst()
	
	if player.swim_hold_timer <= 0.0:
		return
	
	player.swim_hold_timer = max(player.swim_hold_timer - delta, 0.0)
	
	if _burst_timer > 0.0:
		player.velocity.y = lerpf(player.velocity.y, -player.swim_burst_rise_speed, 1.0 - exp(-player.swim_burst_rise_smoothing * delta))
	elif player.velocity.y < 0.0:
		player.velocity.y = lerpf(player.velocity.y, 0.0, player.swim_rise_decay_smoothing)
	else:
		player.velocity.y = lerpf(player.velocity.y, player.swim_neutral_sink_speed, player.swim_neutral_sink_smoothing)


func _next() -> StringName:
	if _burst_timer > 0.0 or player.swim_hold_timer > 0.0 or _is_stroking():
		return &""
	return &"SwimIdle"


func _burst() -> void:
	_burst_queued = false
	_burst_timer = player.swim_burst_duration
	player.swim_hold_timer = player.swim_input_buffer_time
	# Consume the buffered swim press so it can't immediately re-trigger another swim.
	player.swim_input_timer = 0.0
	sprite.play_at_frame(&"swim", 0)


func _is_stroking() -> bool:
	return sprite.playing and sprite.current_animation == &"swim"
