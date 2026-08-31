extends State


const PERIOD: float = 3.0
const AMPLITUDE: float = 35.0

@export var displacement: Curve
@export var floor_check_l: RayCast2D
@export var floor_check_r: RayCast2D

var phase_shift: float = 0.0


func _tick(_delta: float) -> void:
	if _is_blocked():
		phase_shift += PI
	
	sprite.flip_h = entity.velocity.x < 0.0
	entity.velocity.x = AMPLITUDE * displacement.sample(sin(time / PERIOD + phase_shift))


func _is_blocked() -> bool:
	if entity.is_on_wall():
		return true
	if entity.velocity.x > 0.0:
		return entity.is_on_floor() and floor_check_r != null and not floor_check_r.is_colliding()
	if entity.velocity.x < 0.0:
		return floor_check_l != null and not floor_check_l.is_colliding()
	return false
