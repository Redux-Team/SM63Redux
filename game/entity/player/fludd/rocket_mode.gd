extends FluddMode

const FRICTION_KEY: StringName = &"fludd_rocket"

## Sprite shaken and tinted while charging.
@export var sprite: SmartSprite2D

@export_group("Rocket")
## Time held before the rocket launches.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var charge_time: float = 1.0
## Speed set along the launch direction.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var launch_speed: float = 692.5
## Water spent per launch.
@export var fuel_cost: float = 5.0
## Time after a launch before charging can resume.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var recovery_time: float = 0.5
@export_group("Floor Slide")
## Speed set along the body when launching from a floorslide.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var slide_speed: float = 700.0
## Floor friction multiplier after a floorslide launch.
@export var slide_friction_scale: float = 0.2
## Time the floorslide friction multiplier lasts.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var slide_friction_time: float = 0.75
@export_group("Burst")
## Length of the launch particle burst.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var burst_time: float = 0.18
## Scale of the launch particle burst.
@export var burst_scale: float = 2.0

var _charge: float = 0.0
var _charging: bool = false
var _recovery: float = 0.0


func is_committing() -> bool:
	return _charging


func _enter() -> void:
	fludd.begin_spray()
	_resume_charge()


func _tick(delta: float) -> void:
	if _recovery > 0.0:
		_recovery = maxf(_recovery - delta, 0.0)
		return
	
	if not _charging:
		sprite.offset = Vector2.ZERO
		_resume_charge()
		return
	
	_charge += delta
	sprite.self_modulate = lerp(Color.WHITE, Color(1.0, 0.35, 0.35, 1.0), _charge / charge_time)
	sprite.offset = Vector2(randf(), randf()) * _charge * 2
	
	if _charge < charge_time:
		return
	
	_charging = false
	_charge = 0.0
	_recovery = recovery_time
	sprite.self_modulate = Color.WHITE
	sprite.offset = Vector2.ZERO
	_launch()


func _exit() -> void:
	sprite.offset = Vector2.ZERO
	sprite.self_modulate = Color.WHITE
	if _charging:
		fludd.rocket_sfx.stop()
	_charging = false
	_charge = 0.0
	_recovery = 0.0
	fludd.end_spray()


func _resume_charge() -> void:
	if not _charging:
		_charge = 0.0
	_charging = true
	fludd.rocket_sfx.play()


func _launch() -> void:
	var sliding: bool = player.machine.is_active(&"Floorslide")
	var direction: Vector2 = _get_direction(sliding)
	var speed: float = slide_speed if sliding else launch_speed
	if not sliding:
		fludd.launch_off_ground()
	
	player.velocity += direction * (speed - player.velocity.dot(direction))
	fludd.power = 0.0
	fludd.fuel -= fuel_cost
	fludd.burst_particles(burst_time, burst_scale)
	if sliding:
		player.friction_modifiers.set_modifier(FRICTION_KEY, slide_friction_scale, slide_friction_time)


func _get_direction(sliding: bool) -> Vector2:
	var facing: float = float(player.get_facing())
	var heading: Vector2 = Vector2.from_angle(fludd.body_rotation)
	if sliding:
		return heading * facing
	if player.machine.is_active(&"Dive"):
		return Vector2(heading.x * facing, heading.y)
	return Vector2.UP
