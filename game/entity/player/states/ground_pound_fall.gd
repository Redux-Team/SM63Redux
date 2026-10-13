extends PlayerState

@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var fall_speed: float = 815.0
@export_group("Water")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var water_halflife: float = 0.1385
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var swim_speed: float = 50.0


func _enter() -> void:
	player.velocity.y = fall_speed


func _tick(delta: float) -> void:
	if not player.is_in_water():
		return
	
	if player.velocity.y <= swim_speed:
		machine.change_state(&"SwimIdle")
	player.velocity.y = Motion.damp(player.velocity.y, 0.0, water_halflife, delta)


func _next() -> StringName:
	return &"GroundPoundSlam" if player.is_on_floor() else &""
