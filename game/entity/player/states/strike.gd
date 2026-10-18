extends PlayerState

## Time before touching the floor counts as landing.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var land_delay: float = 0.0833
## Time spent recovering after landing before returning to idle.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var recover_time: float = 0.25
## Floor friction multiplier with directional input.
@export var floor_friction_scale: float = 1.0
## Floor friction multiplier without input.
@export var idle_floor_friction_scale: float = 1.39

var _landed_at: float = -1.0


func _enter() -> void:
	_landed_at = -1.0
	player.can_ground_pound = false


func _tick(delta: float) -> void:
	if not player.is_on_floor():
		return
	
	var scale: float = idle_floor_friction_scale if is_zero_approx(player.move_input) else floor_friction_scale
	player.velocity.x = Motion.drift(player.velocity.x, 0.0, player.get_floor_drag_rate() * scale, delta)
	if _landed_at < 0.0 and time > land_delay * player.get_attribute_scale(&"recovery_scale"):
		_landed_at = time


func _exit() -> void:
	player.can_ground_pound = true


func _next() -> StringName:
	if player.is_swimming():
		return &"SwimStrike"
	return &"Idle" if _landed_at >= 0.0 and time - _landed_at >= recover_time * player.get_attribute_scale(&"recovery_scale") else &""
