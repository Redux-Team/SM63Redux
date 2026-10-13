extends PlayerState

## Downward speed at which the jump becomes a fall.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var fall_speed: float = 50.0


func _next() -> StringName:
	if player.can_dive and time > 0.0 and controls.is_just_pressed(&"dive"):
		return &"Dive"
	if player.is_on_floor():
		return &"Idle"
	if player.velocity.y > fall_speed:
		return &"Fall"
	return &""
