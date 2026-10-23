extends PlayerState

@export_group("Launch")
## Caps horizontal speed on takeoff.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var max_horizontal_speed: float = 625.0
## Upward speed set on takeoff.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var rise_speed: float = 192.5
@export_group("Timing")
## Time before diving is allowed again.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var dive_lock_time: float = 0.275
## Time before holding dive starts a dive.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var dive_time: float = 0.2
## Time before touching the floor ends the rollout.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var land_time: float = 0.1
## Time before the rollout can turn into a fall.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var fall_time: float = 0.3
@export_group("Exits")
## Downward speed needed before the rollout turns into a fall.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var fall_min_speed: float = 30.0
## Downward speed that must be reached before a spin can interrupt the rollout.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var spin_min_speed: float = -40.0


func _enter() -> void:
	player.velocity.x = clampf(player.velocity.x, -max_horizontal_speed, max_horizontal_speed)
	player.velocity.y = -player.get_jump_speed(rise_speed)
	player.can_dive = false


func _tick(_delta: float) -> void:
	if not player.can_dive and time >= dive_lock_time:
		player.can_dive = true


func _exit() -> void:
	player.can_dive = true


func _next() -> StringName:
	var grounded: bool = player.has_landed()
	if grounded and time > land_time:
		return &"Idle"
	if not grounded and player.can_dive and time > dive_time and controls.is_held(&"dive"):
		return &"Dive"
	if not grounded and time > fall_time and player.velocity.y > fall_min_speed:
		return &"Fall"
	if controls.is_held(&"spin") and player.velocity.y > spin_min_speed:
		return &"Spin"
	return &""
