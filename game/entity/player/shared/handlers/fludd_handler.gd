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

@export var nozzle_switch_sfx: AudioStream
@export var _spray_particles: GPUParticles2D
@export var player: Player
@export var fludd_fuel: float = 100.0:
	set(fuel):
		fludd_fuel = clamp(fuel, 0.0, FLUDD_FUEL_MAX)
		fludd_fuel_changed.emit(fludd_fuel)
@export var fludd_power: float = 100.0:
	set(power):
		fludd_power = clamp(power, 0.0, FLUDD_POWER_MAX)
		fludd_power_changed.emit(fludd_power)
@export var equipped_nozzle: FluddNozzle:
	set(nozzle):
		equipped_nozzle = nozzle
		if modes:
			modes.select(_mode_names.get(nozzle, &""))
		fludd_nozzle_changed.emit(nozzle)
@export var held_nozzles: Dictionary[FluddNozzle, bool] = {
	FluddNozzle.NONE: true,
	FluddNozzle.HOVER: false,
	FluddNozzle.ROCKET: false,
	FluddNozzle.TURBO: false,
}

@export var modes: ModeMachine
@export var hover_sfx: AudioStreamPlayer2D
@export var spray_loop_sfx: AudioStreamPlayer2D
@export var rocket_sfx: AudioStreamPlayer2D

@export_group("Ground Launch")
@export var fludd_launch_speed: float = -50.0
@export_group("Consumption")
@export var fludd_power_drain_rate: float = 45.0
@export var fludd_fuel_drain_ratio: float = 0.05
@export var fludd_switch_sfx_db: float = -10.0

var body_rotation: float = 0.0

var _spraying: bool = false
var _context: FluddContext = FluddContext.NONE
var _pending_sfx_stop: bool = false
var _burst_timer: float = 0.0
var _mode_names: Dictionary[int, StringName] = {}
var _holding: bool = false


func _ready() -> void:
	for mode: Mode in modes.get_modes():
		var fludd_mode: FluddMode = mode as FluddMode
		if fludd_mode:
			_mode_names.set(fludd_mode.nozzle, mode.name)
	
	modes.select(_mode_names.get(equipped_nozzle, &""))


func _physics_process(delta: float) -> void:
	_holding = Input.is_action_pressed(&"use_fludd")
	
	_tick_sfx()
	_tick_refill(delta)
	_tick_burst(delta)
	_update_spray_angle()
	
	modes.tick(delta, _holding and _can_use_fludd())
	
	var running: FluddMode = get_running_mode()
	if running:
		_consume_fludd(delta, running)
	
	_update_spray_particles()
	_context = FluddContext.NONE


func _tick_sfx() -> void:
	if equipped_nozzle == FluddNozzle.NONE:
		spray_loop_sfx.stop()
		_pending_sfx_stop = false
		_spraying = false
		return
	
	if _pending_sfx_stop and not _spraying:
		spray_loop_sfx.stop()
		_pending_sfx_stop = false


func _tick_refill(delta: float) -> void:
	if player.is_in_water() and not is_equal_approx(fludd_fuel, FLUDD_FUEL_MAX):
		fludd_fuel = FLUDD_FUEL_MAX
	if is_equal_approx(fludd_power, FLUDD_POWER_MAX):
		return
	
	if player.is_on_floor() or player.is_in_water():
		fludd_power = FLUDD_POWER_MAX
		return
	
	var mode: FluddMode = get_selected_mode()
	if mode and mode.recharge_time > 0.0 and not _holding:
		fludd_power += FLUDD_POWER_MAX * delta / mode.recharge_time


func _tick_burst(delta: float) -> void:
	if _burst_timer <= 0.0:
		return
	
	_burst_timer = maxf(_burst_timer - delta, 0.0)
	if _burst_timer > 0.0:
		return
	
	_spray_particles.scale = Vector2.ONE
	_spray_particles.emitting = false


func _update_spray_particles() -> void:
	if _burst_timer > 0.0:
		return
	
	var mode: FluddMode = get_selected_mode()
	_spray_particles.emitting = _spraying and mode != null and mode.continuous_particles


func _update_spray_angle() -> void:
	var mode: FluddMode = get_selected_mode()
	set_spray_angle(mode.get_spray_angle() if mode else player.sprite.rotation)


func _can_use_fludd() -> bool:
	var mode: FluddMode = get_selected_mode()
	return mode != null and \
		mode.has_charge() and \
		fludd_fuel > 0 and \
		player.machine.get_state_name() not in [
			&"Spin", &"SwimSpin", &"Strike", &"Crouch", &"RolloutF", &"GroundPoundFall", &"GroundPoundStart", &"GroundPoundSlam"
		]


func _consume_fludd(delta: float, mode: FluddMode) -> void:
	var power_drain: float = fludd_power_drain_rate * delta
	
	if mode.drains_power and not player.is_on_floor():
		fludd_power -= power_drain
	
	if mode.drains_fuel and not player.is_in_water():
		fludd_fuel -= fludd_fuel_drain_ratio * power_drain


func begin_spray(sfx: AudioStreamPlayer2D = null) -> void:
	if _spraying:
		return
	
	_spraying = true
	if sfx:
		sfx.play()


func begin_spray_loop() -> void:
	_spraying = true
	if spray_loop_sfx.playing:
		return
	
	hover_sfx.stop()
	spray_loop_sfx.play()


func end_spray() -> void:
	_spraying = false
	hover_sfx.stop()
	_pending_sfx_stop = true


func burst_particles(duration: float, scale: float) -> void:
	_burst_timer = duration
	_spray_particles.scale = Vector2.ONE * scale
	_spray_particles.restart()


func launch_off_ground() -> void:
	if player.machine.is_active(&"Grounded"):
		player.machine.change_state(&"IdleJump")
		player.velocity.y = fludd_launch_speed


func get_context() -> FluddContext:
	if player.is_in_water() and equipped_nozzle == FluddNozzle.HOVER:
		return FluddContext.SUBMERGED
	
	return _context


func set_dive_rotation(rotation: float, context: FluddContext) -> void:
	if context != FluddContext.NONE and not spray_loop_sfx.playing and _spraying:
		hover_sfx.stop()
		spray_loop_sfx.play()
	
	body_rotation = rotation
	_context = context


func set_spray_angle(angle: float) -> void:
	_spray_particles.rotation = angle


func is_spraying() -> bool:
	return _spraying


func is_holding() -> bool:
	return _holding


func get_selected_mode() -> FluddMode:
	return modes.get_selected() as FluddMode


func get_running_mode() -> FluddMode:
	return modes.get_running() as FluddMode


func is_committing() -> bool:
	var mode: FluddMode = get_running_mode()
	return mode != null and mode.is_committing()


func is_aiming() -> bool:
	var mode: FluddMode = get_running_mode()
	return mode != null and mode.is_aiming()


func is_turbo_active() -> bool:
	return modes.is_running(&"Turbo")


func _input(event: InputEvent) -> void:
	# FluddNozzle.NONE should never be false, throw an error if it is
	assert(held_nozzles.get(FluddNozzle.NONE))
	
	if event.is_action_pressed(&"switch_fludd_nozzle"):
		var successful_switch: bool = switch_nozzle()
		if successful_switch:
			SFX.build()\
				.set_stream(nozzle_switch_sfx)\
				.set_db(fludd_switch_sfx_db)\
				.set_bus(&"Player")\
				.play()
	if event is InputEventKey:
		if event.keycode == KEY_I:
			player.get_fludd_handler().fludd_fuel = 0


func switch_nozzle() -> bool:
	var nozzle_switched: bool = false
	var previous_nozzle: FluddNozzle = equipped_nozzle
	var candidate_nozzle: int = equipped_nozzle
	
	while not nozzle_switched:
		candidate_nozzle = wrapi(candidate_nozzle + 1, FluddNozzle.NONE, FluddNozzle.MAX)
		if held_nozzles.get(candidate_nozzle):
			equipped_nozzle = candidate_nozzle as FluddNozzle
			nozzle_switched = true
	
	if equipped_nozzle != previous_nozzle:
		fludd_nozzle_changed.emit(equipped_nozzle)
		return true
	
	return false


func switch_nozzle_to(nozzle: FluddNozzle) -> void:
	equipped_nozzle = nozzle
