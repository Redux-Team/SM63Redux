@tool
extends State

const PERIOD: float = 3.0
const AMPLITUDE: float = 35.0

@export var displacement: Curve

@export var floor_check_r: RayCast2D
@export var floor_check_l: RayCast2D
@export var wall_check_l: RayCast2D
@export var wall_check_r: RayCast2D

var start_position: Vector2
var phase_shift: float


func _on_enter() -> void:
	start_position = entity.position



func _on_physics_tick(_delta: float) -> void:
	if (entity.velocity.x > 0 and not floor_check_r.is_colliding())\
	or (entity.velocity.x < 0 and not floor_check_l.is_colliding())\
	or (entity.velocity.x < 0 and wall_check_l.is_colliding())\
	or (entity.velocity.x > 0 and wall_check_r.is_colliding()):
		phase_shift += PI
	
	sprite.flip_h = entity.velocity.x < 0
	
	entity.velocity.x = AMPLITUDE * displacement.sample(
		sin(get_elapsed_time() * (1/PERIOD) + phase_shift)
	)
