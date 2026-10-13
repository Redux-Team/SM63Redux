extends PlayerState

## Time spent stunned before returning to swimming.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var duration: float = 0.6


func _enter() -> void:
	player.can_walk = false
	player.can_ground_pound = false


func _exit() -> void:
	player.can_walk = true
	player.can_ground_pound = true


func _next() -> StringName:
	return &"SwimIdle" if time >= duration else &""
