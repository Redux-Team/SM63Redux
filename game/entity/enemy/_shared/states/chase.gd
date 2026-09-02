class_name ChaseState
extends State


const ACCELERATION_RATIO: float = 0.125

@export var chase_speed: float = 80.0
@export var snap_to_speed_on_enter: bool = false

var _detector: PlayerDetectorComponent


func _bind() -> void:
	_detector = entity.get_component(PlayerDetectorComponent) as PlayerDetectorComponent


func _enter() -> void:
	if snap_to_speed_on_enter:
		entity.velocity.x = _direction_to_target() * chase_speed


func _tick(_delta: float) -> void:
	sprite.flip_h = entity.velocity.x < 0.0
	var step: float = _direction_to_target() * chase_speed * ACCELERATION_RATIO
	entity.velocity.x = clampf(entity.velocity.x + step, -chase_speed, chase_speed)


func _direction_to_target() -> float:
	if not _detector or not is_instance_valid(_detector.target):
		return 0.0
	return signf(_detector.target.global_position.x - entity.global_position.x)
