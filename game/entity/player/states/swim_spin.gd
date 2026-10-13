extends SpinState

@export_custom(PROPERTY_HINT_NONE, "suffix:s") var exit_delay: float = 0.6


func _tick(delta: float) -> void:
	super(delta)
	if controls.swim <= 0.0:
		player.velocity.y = minf(player.velocity.y, 0.0)


func _next() -> StringName:
	return &"SwimIdle" if not controls.is_held(&"spin") and time > exit_delay else &""
