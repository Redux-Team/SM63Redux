extends GoombaState


const CHASE_VELOCITY: float = 80.0


func _enter() -> void:
	goomba.velocity.x = _chase_vector()


func _tick(_delta: float) -> void:
	sprite.flip_h = goomba.velocity.x < 0.0
	goomba.velocity.x = clampf(goomba.velocity.x + _chase_vector() / 8.0, -CHASE_VELOCITY, CHASE_VELOCITY)


func _chase_vector() -> float:
	if not is_instance_valid(goomba.target):
		return 0.0
	return CHASE_VELOCITY * signf(goomba.target.global_position.x - goomba.global_position.x)
