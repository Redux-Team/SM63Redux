extends PlayerState

@export_custom(PROPERTY_HINT_NONE, "suffix:s") var land_delay: float = 0.0833
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var recover_time: float = 0.25
@export var floor_friction_scale: float = 1.0
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
	if _landed_at < 0.0 and time > land_delay:
		_landed_at = time


func _exit() -> void:
	player.can_ground_pound = true


func _next() -> StringName:
	if player.is_in_water():
		return &"SwimStrike"
	return &"Idle" if _landed_at >= 0.0 and time - _landed_at >= recover_time else &""
