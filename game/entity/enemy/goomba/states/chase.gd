@tool
extends State

const CHASE_VELOCITY: float = 80.0

var goomba: Goomba:
	get:
		return entity as Goomba


func _on_enter() -> void:
	goomba.velocity.x = get_chase_vector()


func _on_physics_tick(_delta: float) -> void:
	sprite.flip_h = entity.velocity.x < 0
	
	goomba.velocity.x += get_chase_vector() / 8
	goomba.velocity.x = clampf(goomba.velocity.x, -CHASE_VELOCITY, CHASE_VELOCITY)
	
	#print(entity.velocity.x)


func get_chase_vector() -> float:
	return CHASE_VELOCITY * sign(goomba.target.global_position.x - goomba.global_position.x)
