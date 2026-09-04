extends CheepCheepState


const PERIOD: float = 6.0
const AMPLITUDE: float = 45.0
const EDGE_BOOST: float = 6.0

@export var displacement: Curve
@export var water_check_l: WaterCheckArea
@export var water_check_r: WaterCheckArea
@export var wall_check_l: RayCast2D
@export var wall_check_r: RayCast2D

var _phase: float = 0.0
var _boost: float = 1.0


func _tick(delta: float) -> void:
	var sweep: float = pingpong(_phase, 1.0) * 2.0 - 1.0
	
	if (sweep > 0.0 and (wall_check_r.is_colliding() or not water_check_r.is_in_water())) \
	or (sweep < 0.0 and (wall_check_l.is_colliding() or not water_check_l.is_in_water())):
		_boost = EDGE_BOOST
	
	_phase += _boost * delta / PERIOD
	_boost = lerpf(_boost, 1.0, delta * 4.0)
	
	cheep_cheep.velocity.x = AMPLITUDE * displacement.sample(sweep)
	sprite.flip_h = cheep_cheep.velocity.x < 0.0


func _next() -> StringName:
	return &"Chase" if cheep_cheep.is_player_in_vision() else &""
