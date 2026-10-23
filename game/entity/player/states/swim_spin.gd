extends SpinState

## Submerged state whose sink speed and steering the spin's vertical swim
## follows.
@export var submerged: SubmergedState
## Minimum spin length before releasing spin can end it.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var exit_delay: float = 0.6
## Fraction of the sink speed risen and sunk at while spinning.
@export_range(0.0, 1.0) var speed_ratio: float = 0.5


func _tick(delta: float) -> void:
	super(delta)
	var direction: float = _get_direction()
	if direction != 0.0:
		var gravity_drift: float = \
				player.get_gravity_strength() * submerged.steer_halflife / log(2.0)
		player.velocity.y = Motion.damp(
				player.velocity.y,
				direction * submerged.sink_speed * speed_ratio - gravity_drift,
				submerged.steer_halflife,
				delta,
		)
	else:
		player.velocity.y = minf(player.velocity.y, 0.0)


func overrides_vertical() -> bool:
	return _get_direction() != 0.0


func _next() -> StringName:
	return &"SwimIdle" if not controls.is_held(&"spin") and time > exit_delay else &""


func _get_direction() -> float:
	if controls.is_held(&"jump") and not player.fludd.is_aiming():
		return -1.0
	
	return 1.0 if controls.swim > 0.0 else 0.0
