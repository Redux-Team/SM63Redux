extends Prop

const INERTIA: float = 8.0
const TORQUE_DENOMINATOR: float = 6000.0
const THRESHOLD_KICK: float = 0.025
const LERP_FACTOR: float = 0.0125
const GRAVITY_BASELINE: float = 15.0
const RIDER_TORQUE_SCALE: float = 1.15
const SETTLED_ANGLE: float = 1.0
const DRAG_SPEED_SCALE: float = 0.076 * 32.0

@export var ride_area: RideArea
@export var static_body: StaticBody2D

var _angular_velocity: float = 0.0


static func get_gravity_of(entity: Entity) -> float:
	if entity is Player:
		return (entity as Player).get_gravity_strength() / Engine.physics_ticks_per_second
	
	var gravity: GravityComponent = entity.get_component(GravityComponent) as GravityComponent
	return gravity.get_effective_strength() if gravity else 0.0


func _physics_process(_delta: float) -> void:
	var net_torque: float = 0.0
	for entity: Entity in ride_area.get_riders():
		net_torque += (
				(get_gravity_of(entity) / GRAVITY_BASELINE)
				* ride_area.get_entity_offset(entity).x
				* RIDER_TORQUE_SCALE
		)
	
	var shape: TelescopingShape = object.shape as TelescopingShape if object else null
	var pivot: Node2D = self
	if object:
		pivot = object
	_angular_velocity += (
			(net_torque / TORQUE_DENOMINATOR)
			/ (INERTIA * 0.4 * maxi(shape.units if shape else 1, 1))
	)
	pivot.rotation += _angular_velocity
	if ride_area.has_rider():
		_angular_velocity = lerpf(_angular_velocity, 0.0, LERP_FACTOR)
	else:
		if pivot.rotation > deg_to_rad(SETTLED_ANGLE):
			_angular_velocity -= deg_to_rad(THRESHOLD_KICK)
		elif pivot.rotation < deg_to_rad(-SETTLED_ANGLE):
			_angular_velocity += deg_to_rad(THRESHOLD_KICK)
		
		pivot.rotation = lerpf(pivot.rotation, 0.0, LERP_FACTOR)
		_angular_velocity = lerpf(_angular_velocity, 0.0, LERP_FACTOR)
	
	static_body.constant_linear_velocity.x = pivot.rotation_degrees * DRAG_SPEED_SCALE
