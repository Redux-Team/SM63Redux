extends FluddMode


@export_group("Lift")
@export var force: float = 200.0
@export var impulse: float = 1.3
@export var impulse_speed_cap: float = -500.0
@export var min_rise_speed: float = -50.0
@export var lift_factor_min: float = 0.3
@export var lift_factor_max: float = 0.8
@export var lift_weight: float = 0.57
@export var fall_target_speed: float = -200.0
@export var fall_weight: float = 0.1
@export_group("Speed Clamp")
@export var x_speed_cap: float = 120.0
@export var x_clamp_weight: float = 0.1
@export var x_clamp_rate: float = 20.0
@export_group("Dive")
@export var dive_force: float = 10.0
@export var dive_y_factor: float = 0.0
@export var dive_upward_bias: float = 0.0
@export var dive_dampen_y: float = 0.02
@export var dive_dampen_x: float = 0.03
@export_group("Floor Slide")
@export var slide_force: float = 50.0
@export var slide_y_factor: float = 0.0
@export var slide_upward_bias: float = 0.0
@export var slide_dampen_x: float = 0.03
@export_group("Submerged")
@export var submerged_target_velocity: float = -1000.0
@export var submerged_ease_halflife: float = 0.3


func _enter() -> void:
	fludd.begin_spray(fludd.hover_sfx)


func _tick(delta: float) -> void:
	fludd.launch_off_ground()
	
	match fludd.get_context():
		PlayerFluddHandler.FluddContext.DIVE:
			_dive_spray(delta)
		PlayerFluddHandler.FluddContext.FLOOR_SLIDE:
			_slide_spray(delta)
		PlayerFluddHandler.FluddContext.SUBMERGED:
			fludd.begin_spray_loop()
			_submerged_spray(delta)
		_:
			_hover_spray()
			_clamp_speed(delta)


func _exit() -> void:
	player.effective_midair_max_speed = player.midair_max_speed
	fludd.end_spray()


func _hover_spray() -> void:
	if player.velocity.y < 0.0 and fludd.fludd_power == PlayerFluddHandler.FLUDD_POWER_MAX and not player.is_on_floor():
		player.velocity.y *= impulse
		player.velocity.y = max(player.velocity.y, impulse_speed_cap)
	elif player.velocity.y < min_rise_speed:
		var lift_factor: float = lerpf(lift_factor_min, lift_factor_max, fludd.fludd_power / PlayerFluddHandler.FLUDD_POWER_MAX)
		player.velocity.y = min(lerpf(player.velocity.y, -force * lift_factor, lift_weight), player.velocity.y)
	else:
		player.velocity.y = lerpf(player.velocity.y, fall_target_speed, fall_weight)


func _dive_spray(delta: float) -> void:
	var frame_scale: float = delta * 60.0
	var rotation: float = fludd.body_rotation
	
	player.velocity.y *= 1.0 - dive_dampen_y * frame_scale
	player.velocity.x *= 1.0 - dive_dampen_x * frame_scale
	player.velocity.y += (sin(rotation) * dive_force * dive_y_factor - dive_upward_bias) * pow(frame_scale, 2.0)
	player.velocity.x += cos(rotation) * dive_force * pow(frame_scale, 2.0) * float(player.get_facing())


func _slide_spray(delta: float) -> void:
	var frame_scale: float = delta * 60.0
	var rotation: float = fludd.body_rotation
	
	player.velocity.x *= 1.0 - slide_dampen_x * frame_scale
	player.velocity.y -= slide_upward_bias * pow(frame_scale, 2.0)
	player.velocity.x += cos(rotation) * slide_force * pow(frame_scale, 2.0) * float(player.get_facing())
	player.velocity.y += sin(rotation) * slide_force * slide_y_factor * pow(frame_scale, 2.0)


func _submerged_spray(delta: float) -> void:
	var weight: float = 1.0 - pow(0.5, delta / submerged_ease_halflife)
	player.velocity.y = lerpf(player.velocity.y, submerged_target_velocity, weight)


func _clamp_speed(delta: float) -> void:
	player.effective_midair_max_speed = x_speed_cap
	if absf(player.velocity.x) > x_speed_cap:
		var direction: float = signf(player.velocity.x)
		player.velocity.x = lerpf(player.velocity.x, direction * x_speed_cap, x_clamp_weight * delta * x_clamp_rate)
	
	if player.move_input == 0.0:
		player.velocity.x = lerpf(player.velocity.x, 0.0, x_clamp_weight * delta * x_clamp_rate)
