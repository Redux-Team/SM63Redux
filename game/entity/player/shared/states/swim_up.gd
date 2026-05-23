@tool
extends State

## Peak upward velocity applied during the swim burst (pixels/sec, positive = up in velocity space).
@export var burst_rise_speed: float = 450.0

## How quickly velocity lerps toward the burst target each tick during the active burst window.
## Lower = smoother ramp-up, higher = snappier.
@export var burst_rise_smoothing: float = 0.25

## How quickly upward velocity bleeds off toward neutral float after the burst ends.
## Lower = floatier tail, higher = quicker stop.
@export var rise_decay_smoothing: float = 0.05

## Neutral downward drift velocity while submerged and not actively swimming.
## Kept low so the player feels weightless rather than sinking.
@export var neutral_sink_speed: float = 20.0

## How quickly velocity lerps toward neutral_sink_speed once the burst has fully decayed.
@export var neutral_sink_smoothing: float = 0.1

## How long the active burst window lasts before handing off descent control to Submerged.
@export var burst_duration: float = 0.2

## How long the player's swim input is buffered after this state fires,
## preventing an immediate re-trigger from a held input.
@export var swim_input_buffer_time: float = 0.35

var _burst_timer: float = 0.0


func _on_enter() -> void:
	_burst_timer = burst_duration
	player.swim_buffer_time = swim_input_buffer_time


func _on_physics_tick(delta: float) -> void:
	player.swim_buffer_time = max(player.swim_buffer_time - delta, 0.0)
	_burst_timer = max(_burst_timer - delta, 0.0)
	
	if _burst_timer > 0.0:
		player.velocity.y = lerpf(player.velocity.y, -burst_rise_speed, 1.0 - exp(-burst_rise_smoothing * delta))
	elif player.velocity.y < 0.0:
		player.velocity.y = lerpf(player.velocity.y, 0.0, rise_decay_smoothing)
	else:
		player.velocity.y = lerpf(player.velocity.y, neutral_sink_speed, neutral_sink_smoothing)
	
	if _burst_timer <= 0.0 and player.swim_buffer_time <= 0.0:
		state_machine.change_state(&"Submerged")
