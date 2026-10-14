class_name GroundPoundFallState
extends PlayerState

## Downward speed set on entry and held as the fall cap.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var fall_speed: float = 815.0
@export_group("Pierce")
## The damping that occurs when going through objects, i.e. breakable boxes.
@export_range(0.0, 1.0) var pierce_damping: float = 0.3
@export var pierce_grace_frames: int = 3
@export_group("Water")
## Time for water to halve the fall speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var water_halflife: float = 0.1385
## Fall speed in water below which the pound ends and swimming resumes.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var swim_speed: float = 50.0

var _impact_speed: float = 0.0
var _pierce_speed: float = 0.0
var _grace: int = 0


func _enter() -> void:
	player.velocity.y = fall_speed
	_impact_speed = fall_speed
	_grace = 0


func pierce() -> void:
	_pierce_speed = maxf(_impact_speed, player.velocity.y) * (1.0 - pierce_damping)
	player.velocity.y = _pierce_speed
	_grace = pierce_grace_frames


func _tick(delta: float) -> void:
	if _grace > 0:
		_grace -= 1
		player.velocity.y = maxf(player.velocity.y, _pierce_speed)
	elif player.velocity.y > 0.0:
		_impact_speed = player.velocity.y
	if not player.is_in_water():
		return
	
	if player.velocity.y <= swim_speed:
		machine.change_state(&"SwimIdle")
	player.velocity.y = Motion.damp(player.velocity.y, 0.0, water_halflife, delta)


func _next() -> StringName:
	return &"GroundPoundSlam" if player.is_on_floor() and _grace == 0 else &""
