@tool
extends State

const PERIOD: float = 6.0
const AMPLITUDE: float = 45.0
const EDGE_BOOST: float = 6.0

@export var displacement: Curve
@export var water_check_l: WaterCheckArea
@export var water_check_r: WaterCheckArea
@export var wall_check_l: RayCast2D
@export var wall_check_r: RayCast2D

var _t: float = 0.0
var _boost: float = 1.0


func _on_physics_tick(delta: float) -> void:
	var p: float = pingpong(_t, 1.0) * 2.0 - 1.0
	
	if (p > 0.0 and (wall_check_r.is_colliding() or not water_check_r.is_in_water())) \
	or (p < 0.0 and (wall_check_l.is_colliding() or not water_check_l.is_in_water())):
		_boost = EDGE_BOOST
	
	_t += _boost * delta / PERIOD
	_boost = lerpf(_boost, 1.0, delta * 4.0)
	
	entity.velocity.x = AMPLITUDE * displacement.sample(p)
	sprite.flip_h = entity.velocity.x < 0.0
