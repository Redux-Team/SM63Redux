extends PlayerState

@export_group("Launch")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_horizontal_speed: float = 625.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rise_speed: float = 192.5
@export_group("Timing")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var dive_lock_time: float = 0.275
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var dive_time: float = 0.2
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var land_time: float = 0.1
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var fall_time: float = 0.3
@export_group("Exits")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var fall_min_speed: float = 30.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var spin_min_speed: float = -40.0


func _enter() -> void:
	player.velocity.x = clampf(player.velocity.x, -max_horizontal_speed, max_horizontal_speed)
	player.velocity.y = -rise_speed
	player.can_dive = false


func _tick(_delta: float) -> void:
	if not player.can_dive and time >= dive_lock_time:
		player.can_dive = true


func _exit() -> void:
	player.can_dive = true


func _next() -> StringName:
	var grounded: bool = player.is_on_floor()
	if grounded and time > land_time:
		return &"Idle"
	if not grounded and player.can_dive and time > dive_time and controls.is_held(&"dive"):
		return &"Dive"
	if not grounded and time > fall_time and player.velocity.y > fall_min_speed and _is_spraying_fludd():
		return &"Fall"
	if controls.is_held(&"spin") and player.velocity.y > spin_min_speed:
		return &"Spin"
	return &""


func _is_spraying_fludd() -> bool:
	return controls.is_held(&"use_fludd") and player.fludd.equipped_nozzle != PlayerFludd.Nozzle.NONE
