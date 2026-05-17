@tool
extends State

const CHASE_VELOCITY: float = 80.0

var goomba: Goomba:
	get:
		return entity as Goomba


func _on_enter() -> void:
	entity.velocity.x = get_chase_vector()


func _on_physics_tick(_delta: float) -> void:
	sprite.flip_h = entity.velocity.x < 0
	
	entity.velocity.x += get_chase_vector() / 8
	entity.velocity.x = clampf(entity.velocity.x, -CHASE_VELOCITY, CHASE_VELOCITY)


func get_chase_vector() -> float:
	return CHASE_VELOCITY * sign(entity.target.global_position.x - entity.global_position.x)
