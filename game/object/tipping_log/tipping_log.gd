extends LevelObjectTelescoping


const INERTIA: float = 8.0
const TORQUE_DENOMINATOR: float = 6000.0
const THRESHOLD_KICK: float = 0.025
const LERP_FACTOR: float = 0.0125
const GRAVITY_BASELINE: float = 15.0


@export var ride_area: RideArea
@export var static_body_2d: StaticBody2D


var angular_velocity: float = 0.0
var net_torque: float = 0.0


func _physics_process(_delta: float) -> void:
	net_torque = 0.0
	for entity: Entity in ride_area.get_riders():
		var distance: float = ride_area.get_entity_offset(entity).x
		var gravity: GravityComponent = entity.get_component(GravityComponent) as GravityComponent
		if gravity:
			net_torque += (gravity.get_effective_strength() / GRAVITY_BASELINE) * distance * 1.15
	
	# sum of torques, torque has an inverse relationship with the size of the log so that smaller logs are
	# more sensitive and bigger logs are more resistant.
	angular_velocity += (net_torque / TORQUE_DENOMINATOR) / (INERTIA * (0.4 * max(t_size_x, 1)))
	rotation += angular_velocity
	
	if ride_area.has_rider():
		angular_velocity = lerp(angular_velocity, 0.0, LERP_FACTOR)
	else:
		if rotation > deg_to_rad(1.0):
			angular_velocity -= deg_to_rad(THRESHOLD_KICK)
		elif rotation < deg_to_rad(-1.0):
			angular_velocity += deg_to_rad(THRESHOLD_KICK)
		
		rotation = lerp(rotation, 0.0, LERP_FACTOR)
		angular_velocity = lerp(angular_velocity, 0.0, LERP_FACTOR)
	
	static_body_2d.constant_linear_velocity.x = rotation_degrees * 0.076 * 32
