extends FluddMode


const FRICTION_KEY: StringName = &"fludd_rocket_slide"

@export_group("Rocket")
@export var charge_time: float = 1.0
@export var launch_speed: float = -700.0
@export var fuel_cost: float = 5.0
@export_subgroup("Floor Slide")
@export var slide_speed: float = 700.0
@export var slide_friction_scale: float = 0.2
@export var slide_duration: float = 0.75
@export_subgroup("Burst")
@export var burst_duration: float = 0.18
@export var burst_scale: float = 2.0
@export_subgroup("Recovery")
@export var launch_recovery: float = 0.5

var _charge: float = 0.0
var _charging: bool = false
var _recovery: float = 0.0


func is_committing() -> bool:
	return _charging


func _enter() -> void:
	fludd.begin_spray()
	if not fludd.rocket_sfx.playing:
		_recovery = 0.0
	if _recovery <= 0.0:
		_resume_charge()


func _tick(delta: float) -> void:
	if _recovery > 0.0:
		_recovery = maxf(_recovery - delta, 0.0)
		return
	
	if not _charging:
		_resume_charge()
		return
	
	_charge += delta
	if _charge < charge_time:
		return
	
	_charging = false
	_charge = 0.0
	_recovery = launch_recovery
	_launch()


func _exit() -> void:
	if _charging:
		fludd.rocket_sfx.stop()
	
	if not fludd.is_holding():
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
	var direction: Vector2 = _launch_direction(sliding)
	var speed: float = slide_speed if sliding else absf(launch_speed)
	
	if not sliding:
		fludd.launch_off_ground()
	
	player.velocity += direction * (speed - player.velocity.dot(direction))
	fludd.fludd_power = 0.0
	fludd.fludd_fuel -= fuel_cost
	fludd.burst_particles(burst_duration, burst_scale)
	
	if sliding:
		player.set_friction_modifier(FRICTION_KEY, slide_friction_scale, slide_duration)


func _launch_direction(sliding: bool) -> Vector2:
	var facing: float = float(player.get_facing())
	var heading: Vector2 = Vector2(cos(fludd.body_rotation), sin(fludd.body_rotation))
	
	if sliding:
		return heading * facing
	if player.machine.is_active(&"Dive"):
		return Vector2(heading.x * facing, heading.y)
	
	return Vector2.UP
