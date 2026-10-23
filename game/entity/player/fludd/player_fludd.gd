class_name PlayerFludd
extends Node

signal fuel_changed(fuel: float)
signal power_changed(power: float)
signal nozzle_changed(nozzle: Nozzle)
signal spraying_changed(spraying: bool)

enum Nozzle {
	NONE,
	HOVER,
	ROCKET,
	TURBO,
}

enum Context {
	NONE,
	DIVE,
	FLOOR_SLIDE,
	SUBMERGED,
}

const POWER_MAX: float = 100.0
const FUEL_MAX: float = 100.0

## Player wearing the backpack.
@export var player: Player
## Machine holding one mode per nozzle.
@export var modes: ModeMachine
@export_group("Tank")
## Water left in the tank.
@export var fuel: float = FUEL_MAX:
	set(value):
		fuel = clampf(value, 0.0, FUEL_MAX)
		fuel_changed.emit(fuel)
## Spray power left before needing to recharge.
@export var power: float = POWER_MAX:
	set(value):
		power = clampf(value, 0.0, POWER_MAX)
		power_changed.emit(power)
## Power drained per second while a draining mode runs in the air.
@export_custom(PROPERTY_HINT_NONE, "suffix:/s")
var power_drain_rate: float = 45.0
## Water drained per unit of power drained.
@export var fuel_drain_ratio: float = 0.05
@export_group("Nozzles")
## Nozzle currently selected.
@export var equipped_nozzle: Nozzle = Nozzle.NONE:
	set(value):
		equipped_nozzle = value
		if modes:
			modes.select(_mode_names.get(value, &""))
		nozzle_changed.emit(value)
## Nozzles the player has collected.
@export var held_nozzles: Dictionary[Nozzle, bool] = {
	Nozzle.NONE: true,
	Nozzle.HOVER: false,
	Nozzle.ROCKET: false,
	Nozzle.TURBO: false,
}
## States in which no nozzle can spray.
@export var blocked_states: Array[StringName] = [
	&"Spin",
	&"SwimSpin",
	&"Strike",
	&"Crouch",
	&"RolloutF",
	&"GroundPoundFall",
	&"GroundPoundStart",
	&"GroundPoundSlam",
	&"Glide",
]
@export_group("Launch")
## Upward speed set when spraying lifts the player off the ground.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var launch_speed: float = 42.5
@export_group("Effects")
## Particles used for spray bursts and as the spray origin.
@export var spray_particles: GPUParticles2D
## Water stream shown while a continuous nozzle sprays.
@export var spray_stream: SprayStream
## Sound played when hovering starts.
@export var hover_sfx: AudioStreamPlayer2D
## Sound looped while spraying.
@export var spray_loop_sfx: AudioStreamPlayer2D
## Sound played while the rocket charges.
@export var rocket_sfx: AudioStreamPlayer2D
## Sound played when switching nozzles.
@export var switch_sfx: AudioStream
## Volume of the nozzle switch sound.
@export var switch_sfx_db: float = -10.0

## Body angle reported by the dive and floorslide states for directional
## spraying.
var body_rotation: float = 0.0

var _spraying: bool = false:
	set(value):
		if _spraying == value:
			return
		_spraying = value
		spraying_changed.emit(value)
var _holding: bool = false
var _stop_sfx_pending: bool = false
var _burst_time: float = 0.0
var _launch_time: float = 0.0
var _context: Context = Context.NONE
var _mode_names: Dictionary[Nozzle, StringName] = {}


func _ready() -> void:
	for mode: Mode in modes.get_modes():
		var fludd_mode: FluddMode = mode as FluddMode
		if fludd_mode:
			_mode_names[fludd_mode.nozzle] = mode.name
	
	modes.select(_mode_names.get(equipped_nozzle, &""))


func tick(delta: float) -> void:
	_holding = player.controls.is_held(&"use_fludd")
	if player.controls.is_just_pressed(&"switch_nozzle") and switch_nozzle():
		SFX.build().set_stream(switch_sfx).set_db(switch_sfx_db).set_bus(&"Player").play()
	
	_tick_sfx()
	_tick_refill(delta)
	_tick_burst(delta)
	_launch_time = maxf(_launch_time - delta, 0.0)
	var selected: FluddMode = get_selected_mode()
	spray_particles.rotation = selected.get_spray_angle() if selected else player.sprite.rotation
	modes.tick(delta, _holding and _can_spray())
	
	var running: FluddMode = get_running_mode()
	if running:
		_drain(running, delta)
	
	spray_stream.profile = selected.spray if selected else null
	spray_stream.power_ratio = power / POWER_MAX
	spray_stream.emitting = _spraying and selected != null and selected.continuous_spray
	_context = Context.NONE


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
	_stop_sfx_pending = true


func burst_particles(duration: float, scale: float) -> void:
	_burst_time = duration
	spray_particles.scale = Vector2.ONE * scale
	spray_particles.restart()


func mark_launch(duration: float) -> void:
	_launch_time = duration


func is_launching() -> bool:
	return _launch_time > 0.0


func launch_off_ground() -> void:
	if player.machine.is_active(&"Grounded"):
		player.machine.change_state(&"IdleJump")
		player.velocity.y = -launch_speed


func set_body_rotation(rotation: float, context: Context) -> void:
	if context != Context.NONE and _spraying and not spray_loop_sfx.playing:
		hover_sfx.stop()
		spray_loop_sfx.play()
	
	body_rotation = rotation
	_context = context


func get_context() -> Context:
	if player.is_swimming() and equipped_nozzle == Nozzle.HOVER:
		return Context.SUBMERGED
	return _context


func get_selected_mode() -> FluddMode:
	return modes.get_selected() as FluddMode


func get_running_mode() -> FluddMode:
	return modes.get_running() as FluddMode


func is_spraying() -> bool:
	return _spraying


func is_committing() -> bool:
	var mode: FluddMode = get_running_mode()
	return mode != null and mode.is_committing()


func is_aiming() -> bool:
	var mode: FluddMode = get_running_mode()
	return mode != null and mode.is_aiming()


func is_turbo_active() -> bool:
	var mode: FluddMode = get_running_mode()
	return mode != null and mode.nozzle == Nozzle.TURBO


func switch_nozzle() -> bool:
	var previous: Nozzle = equipped_nozzle
	var candidate: int = equipped_nozzle
	for _i: int in Nozzle.size():
		candidate = wrapi(candidate + 1, 0, Nozzle.size())
		if held_nozzles.get(candidate, false):
			equipped_nozzle = candidate as Nozzle
			break
	
	return equipped_nozzle != previous


func _tick_sfx() -> void:
	if equipped_nozzle == Nozzle.NONE:
		spray_loop_sfx.stop()
		_stop_sfx_pending = false
		_spraying = false
		return
	
	if _stop_sfx_pending and not _spraying:
		spray_loop_sfx.stop()
		_stop_sfx_pending = false


func _tick_refill(delta: float) -> void:
	if player.is_in_water() and not is_equal_approx(fuel, FUEL_MAX):
		fuel = FUEL_MAX
	if is_equal_approx(power, POWER_MAX):
		return
	
	if player.is_on_floor() or player.is_swimming():
		power = POWER_MAX
		return
	
	var mode: FluddMode = get_selected_mode()
	if mode and mode.recharge_time > 0.0 and not _holding:
		power += POWER_MAX * delta / mode.recharge_time


func _tick_burst(delta: float) -> void:
	if _burst_time <= 0.0:
		return
	
	_burst_time = maxf(_burst_time - delta, 0.0)
	if _burst_time <= 0.0:
		spray_particles.scale = Vector2.ONE
		spray_particles.emitting = false


func _can_spray() -> bool:
	var mode: FluddMode = get_selected_mode()
	return (
			mode != null
			and mode.has_charge()
			and fuel > 0.0
			and not blocked_states.has(player.machine.get_state_name())
	)


func _drain(mode: FluddMode, delta: float) -> void:
	var drained: float = power_drain_rate * delta
	if mode.drains_power and not player.is_on_floor():
		power -= drained
	if mode.drains_fuel and not player.is_in_water():
		fuel -= fuel_drain_ratio * drained
