extends FluddMode

const MODIFIER_KEY: StringName = &"fludd_turbo"

@export_group("Turbo")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var speed: float = 450.0
@export_group("Underwater Aim")
@export_range(0.0, 90.0, 0.1, "degrees") var max_up_angle: float = 30.0
@export_range(0.0, 90.0, 0.1, "degrees") var max_down_angle: float = 30.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var aim_halflife: float = 0.08
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var aim_acceleration: float = 1200.0

var _aiming: bool = false
var _aim_degrees: float = 0.0


func is_aiming() -> bool:
	return _aiming


func _enter() -> void:
	fludd.begin_spray_loop()
	player.friction_modifiers.set_modifier(MODIFIER_KEY, 0.0)


func _tick(delta: float) -> void:
	player.ground_speed_override = speed
	player.air_speed_override = speed
	if not player.is_in_water():
		_stop_aiming()
		return
	
	if not _aiming:
		_aiming = true
		player.gravity_modifiers.set_modifier(MODIFIER_KEY, 0.0)
	_aim(delta)


func _exit() -> void:
	_stop_aiming()
	player.friction_modifiers.clear_modifier(MODIFIER_KEY)
	player.ground_speed_override = 0.0
	player.air_speed_override = 0.0
	fludd.end_spray()


func get_spray_angle() -> float:
	return float(player.get_facing()) * (0.5 * PI + deg_to_rad(player.sprite.local_rotation))


func _aim(delta: float) -> void:
	var aim: float = float(player.controls.is_held(&"crouch")) - float(player.controls.is_held(&"jump"))
	var target: float = aim * (max_down_angle if aim > 0.0 else max_up_angle)
	_aim_degrees = Motion.damp(_aim_degrees, target, aim_halflife, delta)
	var direction: Vector2 = Vector2.from_angle(deg_to_rad(_aim_degrees))
	direction.x *= float(player.get_facing())
	player.velocity = player.velocity.move_toward(direction * maxf(speed, player.velocity.length()), aim_acceleration * delta)
	player.sprite.local_rotation = _aim_degrees


func _stop_aiming() -> void:
	if not _aiming:
		return
	
	_aiming = false
	_aim_degrees = 0.0
	player.gravity_modifiers.clear_modifier(MODIFIER_KEY)
	player.sprite.local_rotation = 0.0
