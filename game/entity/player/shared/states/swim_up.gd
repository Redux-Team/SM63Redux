extends PlayerState


## How quickly velocity lerps toward the burst target each tick during the active burst window.

## How quickly upward velocity bleeds off toward neutral float after the burst ends.

## Neutral downward drift velocity while submerged and not actively swimming.



## How long the player's swim input is buffered after this state fires,

var _burst_timer: float = 0.0


func _enter() -> void:
	_burst_timer = player.swim_burst_duration
	player.swim_buffer_time = player.swim_input_buffer_time
	# Consume the buffered swim press so it can't immediately re-trigger another swim.
	player.swim_input_timer = 0.0


func _tick(delta: float) -> void:
	player.swim_buffer_time = max(player.swim_buffer_time - delta, 0.0)
	_burst_timer = max(_burst_timer - delta, 0.0)
	
	if _burst_timer > 0.0:
		player.velocity.y = lerpf(player.velocity.y, -player.swim_burst_rise_speed, 1.0 - exp(-player.swim_burst_rise_smoothing * delta))
	elif player.velocity.y < 0.0:
		player.velocity.y = lerpf(player.velocity.y, 0.0, player.swim_rise_decay_smoothing)
	else:
		player.velocity.y = lerpf(player.velocity.y, player.swim_neutral_sink_speed, player.swim_neutral_sink_smoothing)


func _next() -> StringName:
	if player.swim_buffer_time > 0.0:
		return &""
	if not player.is_input_swim or _burst_timer <= 0.0:
		return &"SwimIdle"
	return &""
