class_name PlayerFluddHandler
extends Node


enum FluddNozzle {
	NONE,
	HOVER,
	ROCKET,
	TURBO,
	MAX
}

enum FluddContext {
	NONE,
	DIVE,
	FLOOR_SLIDE,
	SUBMERGED,
}

const FLUDD_POWER_MAX: float = 100.0
const FLUDD_FUEL_MAX: float = 100.0


signal fludd_fuel_changed(fuel_amount: float)
signal fludd_power_changed(power_amount: float)
signal fludd_nozzle_changed(nozzle: FluddNozzle)






@export_group("")
@export var nozzle_switch_sfx: AudioStream
@export var _spray_particles: GPUParticles2D
@export var player: Player
@export var fludd_fuel: float = 100.0:
	set(ff):
		fludd_fuel = clamp(ff, 0.0, FLUDD_FUEL_MAX)
		fludd_fuel_changed.emit(fludd_fuel)
@export var fludd_power: float = 100.0:
	set(fp):
		fludd_power = clamp(fp, 0.0, FLUDD_POWER_MAX)
		fludd_power_changed.emit(fludd_power)
@export var equipped_nozzle: FluddNozzle:
	set(en):
		equipped_nozzle = en
		fludd_nozzle_changed.emit(en)
@export var held_nozzles: Dictionary[FluddNozzle, bool] = {
	FluddNozzle.NONE: true,
	FluddNozzle.HOVER: false,
	FluddNozzle.ROCKET: false,
	FluddNozzle.TURBO: false,
}

@export var _hover_fludd_particles: GPUParticles2D
@export var _hover_sfx: AudioStreamPlayer2D
@export var _spray_loop_sfx: AudioStreamPlayer2D

var _hover_active: bool = false:
	set(ha):
		_hover_active = ha
		_hover_fludd_particles.emitting = ha

var _dive_rotation: float = 0.0
var _fludd_context: FluddContext = FluddContext.NONE
var _pending_sfx_stop: bool = false


func _physics_process(delta: float) -> void:
	_tick_sfx()
	_tick_refill()
	_update_spray_angle()
	
	if Input.is_action_pressed(&"use_fludd") and _can_use_fludd():
		_update_submerged_context()
		_tick_nozzle(delta)
		_consume_fludd(delta)
	else:
		_deactivate_fludd()


func _tick_sfx() -> void:
	if equipped_nozzle == FluddNozzle.NONE:
		_spray_loop_sfx.stop()
		_pending_sfx_stop = false
		_hover_active = false
		return
	
	if _pending_sfx_stop and not _hover_active:
		_spray_loop_sfx.stop()
		_pending_sfx_stop = false


func _tick_refill() -> void:
	if (player.is_on_floor() or player.is_in_water()) and not is_equal_approx(fludd_power, FLUDD_POWER_MAX):
		fludd_power = FLUDD_POWER_MAX
	if player.is_in_water() and not is_equal_approx(fludd_fuel, FLUDD_FUEL_MAX):
		fludd_fuel = FLUDD_FUEL_MAX


func _update_spray_angle() -> void:
	if _fludd_context in [FluddContext.DIVE, FluddContext.FLOOR_SLIDE]:
		const RIGHT: float = PI / 2.0
		if player.sprite.flip_h:
			set_spray_angle((3.0 * RIGHT) - deg_to_rad(player.sprite.local_rotation))
		else:
			set_spray_angle(RIGHT + deg_to_rad(player.sprite.local_rotation))
	else:
		set_spray_angle(player.sprite.rotation)


func _update_submerged_context() -> void:
	if player.is_in_water() and equipped_nozzle == FluddNozzle.HOVER:
		if _fludd_context != FluddContext.SUBMERGED:
			_fludd_context = FluddContext.SUBMERGED
			_hover_active = true
			if not _spray_loop_sfx.playing:
				_hover_sfx.stop()
				_spray_loop_sfx.play()
	elif _fludd_context == FluddContext.SUBMERGED:
		_fludd_context = FluddContext.NONE


func _tick_nozzle(delta: float) -> void:
	match equipped_nozzle:
		FluddNozzle.HOVER:
			_handle_grounded_launch()
			match _fludd_context:
				FluddContext.DIVE:
					_hover_dive_fludd_logic(delta)
				FluddContext.FLOOR_SLIDE:
					_hover_floor_slide_fludd_logic(delta)
				FluddContext.SUBMERGED:
					_hover_submerged_fludd_logic(delta)
				_:
					_hover_fludd_logic()
					_apply_x_speed_clamp(delta)
		FluddNozzle.ROCKET:
			_rocket_fludd_logic(delta)
		FluddNozzle.TURBO:
			_turbo_fludd_logic(delta)


func _can_use_fludd() -> bool:
	return fludd_power > 0 and \
		fludd_fuel > 0 and \
		player.machine.get_state_name() not in [
			&"Spin", &"Strike", &"Crouch", &"RolloutF", &"GroundPoundFall", &"GroundPoundStart", &"GroundPoundSlam"
		]


func _deactivate_fludd() -> void:
	player.effective_midair_max_speed = player.midair_max_speed
	player.is_using_hover_fludd = false
	_fludd_context = FluddContext.NONE
	_hover_active = false
	_hover_sfx.stop()
	_pending_sfx_stop = true


func _hover_fludd_logic() -> void:
	player.is_using_hover_fludd = true
	if not _hover_active:
		_hover_active = true
		_hover_sfx.play()
	
	if player.velocity.y < 0.0 and fludd_power == FLUDD_POWER_MAX and not player.is_on_floor():
		player.velocity.y *= player.fludd_impulse
		player.velocity.y = max(player.velocity.y, player.fludd_impulse_speed_cap)
	elif player.velocity.y < player.fludd_hover_min_rise_speed:
		var fludd_velocity_factor: float = lerpf(player.fludd_lift_factor_min, player.fludd_lift_factor_max, fludd_power / FLUDD_POWER_MAX)
		player.velocity.y = min(lerpf(player.velocity.y, -player.fludd_force * fludd_velocity_factor, player.fludd_lift_weight), player.velocity.y)
	else:
		player.velocity.y = lerpf(player.velocity.y, player.fludd_fall_target_speed, player.fludd_fall_weight)


func _hover_dive_fludd_logic(delta: float) -> void:
	player.is_using_hover_fludd = true
	_hover_active = true
	
	var fps: float = delta * 60.0
	player.velocity.y *= 1.0 - player.dive_fludd_dampen_y * fps
	player.velocity.x *= 1.0 - player.dive_fludd_dampen_x * fps
	player.velocity.y += (sin(_dive_rotation) * player.dive_fludd_force * player.dive_fludd_y_factor - player.dive_fludd_upward_bias) * pow(fps, 2.0)
	player.velocity.x += cos(_dive_rotation) * player.dive_fludd_force * player.dive_fludd_x_factor * pow(fps, 2.0) * float(player.get_facing())


func _hover_floor_slide_fludd_logic(delta: float) -> void:
	player.is_using_hover_fludd = true
	_hover_active = true
	
	var fps: float = delta * 60.0
	player.velocity.x *= 1.0 - player.slide_fludd_dampen_x * fps
	player.velocity.y -= player.slide_fludd_upward_bias * pow(fps, 2.0)
	player.velocity.x += cos(_dive_rotation) * player.slide_fludd_force * player.slide_fludd_x_factor * pow(fps, 2.0) * float(player.get_facing())
	player.velocity.y += sin(_dive_rotation) * player.slide_fludd_force * player.slide_fludd_y_factor * pow(fps, 2.0)


func _hover_submerged_fludd_logic(delta: float) -> void:
	player.is_using_hover_fludd = true
	_hover_active = true
	
	var t: float = 1.0 - pow(0.5, delta / player.submerged_fludd_ease_halflife)
	player.velocity.y = lerpf(player.velocity.y, player.submerged_fludd_target_velocity, t)


func _rocket_fludd_logic(_delta: float) -> void:
	pass


func _turbo_fludd_logic(_delta: float) -> void:
	pass


func _handle_grounded_launch() -> void:
	if player.machine.is_active(&"Grounded"):
		player.machine.change_state(&"IdleJump")
		player.velocity.y = player.fludd_launch_speed


func _apply_x_speed_clamp(delta: float) -> void:
	player.effective_midair_max_speed = player.fludd_x_speed_cap
	if absf(player.velocity.x) > player.fludd_x_speed_cap:
		var sign_x: float = signf(player.velocity.x)
		player.velocity.x = lerpf(player.velocity.x, sign_x * player.fludd_x_speed_cap, player.fludd_x_clamp_weight * delta * player.fludd_x_clamp_rate)
	
	if player.move_dir == 0.0:
		player.velocity.x = lerpf(player.velocity.x, 0.0, player.fludd_x_clamp_weight * delta * player.fludd_x_clamp_rate)


func _consume_fludd(delta: float) -> void:
	var power_drain: float = (player.fludd_power_drain_rate * player.fludd_consume_rate) * delta
	
	if not player.is_on_floor():
		fludd_power -= power_drain
	
	if not player.is_in_water():
		fludd_fuel -= player.fludd_fuel_drain_ratio * power_drain


func set_dive_rotation(rotation: float, context: FluddContext) -> void:
	if context != FluddContext.NONE and not _spray_loop_sfx.playing and _hover_active:
		_hover_sfx.stop()
		_spray_loop_sfx.play()
	
	_dive_rotation = rotation
	_fludd_context = context


func set_spray_angle(angle: float) -> void:
	_spray_particles.rotation = angle


func is_hover_active() -> bool:
	return _hover_active


## Whether the equipped nozzle is currently spraying. Nozzle logic sets [member _hover_active], so
## rocket and turbo start driving the plume as soon as their logic does the same.
func is_spraying() -> bool:
	return _hover_active


func _input(event: InputEvent) -> void:
	# FluddNozzle.NONE should never be false, throw an error if it is
	assert(held_nozzles.get(FluddNozzle.NONE))
	
	if event.is_action_pressed(&"switch_fludd_nozzle"):
		var successful_switch: bool = switch_nozzle()
		if successful_switch:
			SFX.build()\
				.set_stream(nozzle_switch_sfx)\
				.set_db(player.fludd_switch_sfx_db)\
				.set_bus(&"Player")\
				.play()
	if event is InputEventKey:
		if event.keycode == KEY_I:
			player.get_fludd_handler().fludd_fuel = 0


func switch_nozzle() -> bool:
	var nozzle_switched: bool = false
	var t_equipped: FluddNozzle = equipped_nozzle
	var try_nozzle: int = equipped_nozzle
	
	while not nozzle_switched:
		try_nozzle = wrapi(try_nozzle + 1, FluddNozzle.NONE, FluddNozzle.MAX)
		if held_nozzles.get(try_nozzle):
			equipped_nozzle = try_nozzle as FluddNozzle
			nozzle_switched = true
	
	if equipped_nozzle != t_equipped:
		fludd_nozzle_changed.emit(equipped_nozzle)
		return true
	
	return false


func switch_nozzle_to(nozzle: FluddNozzle) -> void:
	equipped_nozzle = nozzle
