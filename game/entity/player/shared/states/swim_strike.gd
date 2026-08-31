extends PlayerState


func _enter() -> void:
	player.can_walk = false
	player.can_ground_pound = false


func _exit() -> void:
	player.can_walk = true
	player.can_ground_pound = true


func _next() -> StringName:
	return &"SwimIdle" if time >= player.swim_strike_duration else &""
