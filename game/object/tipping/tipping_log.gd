extends LevelObjectTelescoping


const INERTIA: float = 8.0
const TORQUE_DENOMINATOR: float = 6000.0
const THRESHOLD_KICK: float = 0.025
const LERP_FACTOR: float = 0.0125
const GRAVITY_BASELINE: float = 15.0
const RIDER_TORQUE_SCALE: float = 1.15
const SETTLED_ANGLE: float = 1.0
const DRAG_SPEED_SCALE: float = 0.076 * 32.0


@export var ride_area: RideArea
@export var static_body_2d: StaticBody2D


var _angular_velocity: float = 0.0


func _physics_process(_delta: float) -> void:
	var net_torque: float = 0.0
	for entity: Entity in ride_area.get_riders():
		var distance: float = ride_area.get_entity_offset(entity).x
		var gravity: GravityComponent = entity.get_component(GravityComponent) as GravityComponent
		if gravity:
			net_torque += (gravity.get_effective_strength() / GRAVITY_BASELINE) * distance * RIDER_TORQUE_SCALE
	
	# sum of torques, torque has an inverse relationship with the size of the log so that smaller logs are
	# more sensitive and bigger logs are more resistant.
	_angular_velocity += (net_torque / TORQUE_DENOMINATOR) / (INERTIA * (0.4 * max(t_size_x, 1)))
	rotation += _angular_velocity
	
	if ride_area.has_rider():
		_angular_velocity = lerp(_angular_velocity, 0.0, LERP_FACTOR)
	else:
		if rotation > deg_to_rad(SETTLED_ANGLE):
			_angular_velocity -= deg_to_rad(THRESHOLD_KICK)
		elif rotation < deg_to_rad(-SETTLED_ANGLE):
			_angular_velocity += deg_to_rad(THRESHOLD_KICK)
		
		rotation = lerp(rotation, 0.0, LERP_FACTOR)
		_angular_velocity = lerp(_angular_velocity, 0.0, LERP_FACTOR)
	
	static_body_2d.constant_linear_velocity.x = rotation_degrees * DRAG_SPEED_SCALE
