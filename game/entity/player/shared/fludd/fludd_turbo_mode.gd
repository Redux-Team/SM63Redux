extends FluddMode


const MODIFIER_KEY: StringName = &"fludd_turbo"

@export_group("Turbo")
@export var turbo_speed: float = 450.0
@export_subgroup("Underwater Aim")
@export var angle_min: float = 30.0
@export var angle_max: float = 30.0
@export var aim_turn_halflife: float = 0.08
@export var aim_acceleration: float = 1200.0

var _aiming: bool = false
var _aim_degrees: float = 0.0


func is_aiming() -> bool:
	return _aiming


func _enter() -> void:
	fludd.begin_spray_loop()
	player.set_friction_modifier(MODIFIER_KEY, 0.0)


func _tick(delta: float) -> void:
	player.effective_run_max_speed = turbo_speed
	player.effective_midair_max_speed = turbo_speed
	
	if not player.is_in_water():
		_stop_aiming()
		return
	
	if not _aiming:
		_aiming = true
		player.set_gravity_modifier(MODIFIER_KEY, 0.0)
	
	_apply_aim(delta)


func _exit() -> void:
	_stop_aiming()
	player.clear_friction_modifier(MODIFIER_KEY)
	player.effective_run_max_speed = player.run_max_speed
	player.effective_midair_max_speed = player.midair_max_speed
	fludd.end_spray()


func get_spray_angle() -> float:
	return float(player.get_facing()) * (PI / 2.0 + deg_to_rad(player.sprite.local_rotation))


func _apply_aim(delta: float) -> void:
	var aim: float = Input.get_axis(&"jump", &"crouch")
	var target: float = aim * (angle_max if aim > 0.0 else angle_min)
	
	_aim_degrees = lerpf(_aim_degrees, target, 1.0 - pow(0.5, delta / aim_turn_halflife))
	
	var facing: float = float(player.get_facing())
	var radians: float = deg_to_rad(_aim_degrees)
	var direction: Vector2 = Vector2(cos(radians) * facing, sin(radians))
	var speed: float = maxf(turbo_speed, player.velocity.length())
	
	player.velocity = player.velocity.move_toward(direction * speed, aim_acceleration * delta)
	player.sprite.local_rotation = _aim_degrees


func _stop_aiming() -> void:
	if not _aiming:
		return
	
	_aiming = false
	_aim_degrees = 0.0
	player.clear_gravity_modifier(MODIFIER_KEY)
	player.sprite.local_rotation = 0.0
