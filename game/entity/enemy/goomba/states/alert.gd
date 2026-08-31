extends GoombaState


const HOP: Vector2 = Vector2(-30.0, -200.0)
const HOP_IN_WATER: Vector2 = Vector2(-30.0, -50.0)
const HOP_IN_AIR: Vector2 = Vector2(-30.0, 10.0)
const LANDING_MIN_FRAMES: int = 5
const LANDING_DELAY: float = 0.1

var _landed_at: float = -1.0


func _enter() -> void:
	_landed_at = -1.0
	if not goomba.is_on_floor():
		goomba.local_velocity = HOP_IN_AIR
	else:
		goomba.local_velocity = HOP_IN_WATER if goomba.is_in_water() else HOP
	sprite.play(&"alert_jump")


func _tick(_delta: float) -> void:
	if _landed_at >= 0.0:
		return
	
	if not goomba.is_on_floor() and goomba.velocity.y > 0.0:
		sprite.play(&"alert_fall")
	
	if goomba.is_on_floor() and frames > LANDING_MIN_FRAMES:
		sprite.play(&"alert_landed")
		_landed_at = time


func _next() -> StringName:
	if _landed_at >= 0.0 and time - _landed_at >= LANDING_DELAY:
		return &"Chase"
	return &""
