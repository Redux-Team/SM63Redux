# TODO - The player is in a relatively stable state; however, I do plan
# on reworking the API in the future, especially when it comes to class variables
# affecting states.
class_name Player
extends Entity


signal swimming_changed(swimming: bool)


const BUFFER_ACTIONS: PackedStringArray = ["jump"]
var buffer_dictionary: Dictionary[String, float]

@export_group("Movement Variables")
@export_subgroup("Horizontal Movement")
@export var walk_acceleration: float = 20.0
@export var turn_speed: float = 2.5
@export var midair_turn_speed: float = 1.0
@export var air_resistance: float = 1.0
@export_subgroup("Vertical Movement")
@export var jump_strength: float = 340.0
@export var double_jump_strength: float = 420.0
@export var triple_jump_strength: float = 500.0
@export var jump_chain_time: float = 0.15
@export_subgroup("Underwater Movement")
@export var water_resistance: float = 0.6
@export var swim_up_strength: float = 150.0
@export var water_y_cap: float = 35.0
@export var water_sink_rate: float = 0.125
@export var water_drag_x: float = 1.001

@export_group("Speed Limits")
@export var run_max_speed: float = 250.0
@export var midair_max_speed: float = 190.0
@export var terminal_velocity_x: float = 500.0
@export var terminal_velocity_y: float = 725.0
@export_group("Ground")
@export var ground_friction_flat: float = 0.3
@export var ground_friction_divisor: float = 1.15
@export var slope_normal_threshold: float = 0.999
@export var slope_stick_speed: float = 0.5
@export var dry_friction: float = 0.4

@export_group("Air Control")
@export var air_control_normal: float = 0.85
@export var air_control_spin: float = 0.35
@export var air_turn_boost: float = 2.8
@export var air_turn_boost_spin: float = 1.4
@export var air_turn_speed_threshold: float = 10.0
@export var air_over_speed_decel: float = 0.1

@export_group("Jump")
## How much upward speed survives releasing jump while still rising. 1.0 disables the cut.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.45
@export var jump_buffer_window: float = 0.2
@export var triple_jump_min_speed: float = 120.0
@export var jump_spin_min_speed: float = -55.0
@export var fall_spin_min_speed: float = 100.0
@export var idle_jump_fall_speed: float = 50.0

@export_group("Dive")
@export_subgroup("Launch")
@export var dive_target_speed: float = 900.0
@export var dive_time_to_target_speed: float = 0.058
@export var dive_launch_y_boost: float = 80.0
@export var dive_neutral_launch_y_cap: float = -180.0
@export var dive_launch_y_min: float = -220.0
@export var dive_launch_y_max: float = 300.0
@export_subgroup("Ground Pound Conversion")
@export var dive_gp_conversion_window: float = 0.1
@export var dive_gp_redirect_angle_deg: float = 36.0
@export_subgroup("Ground Physics")
@export var dive_ground_flat_decel: float = 6.42
@export var dive_ground_proportional_decel: float = 0.0196
@export var dive_landing_friction_multiplier: float = 2.0
@export var dive_slide_stop_threshold: float = 30.0
@export_subgroup("Air Control")
@export var dive_air_control: float = 0.35
@export var dive_air_resistance: float = 0.0
@export var dive_over_speed_decel: float = 3.0
@export_subgroup("Rotation")
@export var dive_air_rotation_blend: float = 0.2
@export var dive_ground_rotation_blend: float = 0.15
@export var dive_ground_rotation_blend_fast: float = 0.3
@export var dive_landing_rotation_smooth_duration: float = 0.3
@export var dive_grounded_angle_deg: float = 90.0
@export var dive_rotation_min_deg: float = 90.0
@export var dive_rotation_max_deg: float = 180.0
@export var dive_rotation_curve: Curve
@export var dive_y_velocity_to_rotation_offset_curve: Curve
@export var dive_y_velocity_curve_min: float = -300.0
@export var dive_y_velocity_curve_max: float = 300.0
@export_subgroup("Recovery")
@export var dive_slide_stop_duration: float = 0.133
@export var dive_rollout_jump_velocity: float = -214.0
@export var dive_reset_decel: float = 5.0

@export_group("Floor Slide")
@export var slide_flat_angle: float = 90.0
@export var slide_max_nosedive_angle: float = 45.0
@export var slide_angle_lerp_speed: float = 0.5
@export var slide_airborne_nosedive_speed: float = 0.15
@export var slide_ledge_buffer_time: float = 0.15
@export var slide_friction_scale: float = 1.6
@export var slide_air_gravity_add: float = 1.0
@export var slide_terminal_x_divisor: float = 2.0
@export var slide_terminal_y_divisor: float = 1.5
@export var slide_exit_speed: float = 5.0
@export var slide_rollout_min_speed: float = 50.0

@export_group("Spin")
@export var spin_gravity_scale: float = 0.67
@export var spin_fast_duration: float = 0.25
@export var spin_gravity_resume_time: float = 0.1
@export var spin_duration: float = 0.5
@export var spin_rise_from_fall: float = -35.0
@export var spin_rise_boost: float = 50.0
@export var spin_fall_cap: float = 270.0

@export_group("Backflip")
@export var backflip_x_boost: float = 280.0
@export var backflip_y_velocity: float = -400.0
@export var backflip_up_x_boost: float = 50.0
@export var backflip_up_y_velocity: float = -475.0
@export var backflip_spin_min_speed: float = 155.0

@export_group("Rollout")
@export var rollout_x_clamp: float = 625.0
@export var rollout_y_velocity: float = -200.0
@export var rollout_dive_lock_time: float = 0.275
@export var rollout_idle_time: float = 0.1
@export var rollout_dive_time: float = 0.2
@export var rollout_fall_time: float = 0.3
@export var rollout_fall_min_speed: float = 30.0
@export var rollout_spin_min_speed: float = -40.0

@export_group("Ground Pound")
@export var gp_start_rise_speed: float = -38.0
@export var gp_start_duration: float = 0.3
@export var gp_fall_speed: float = 800.0
@export var gp_water_slow_lerp: float = 0.08
@export var gp_water_swim_speed: float = 50.0
@export var gp_slam_exit_delay: float = 0.3

@export_group("Swim")
@export var swim_burst_rise_speed: float = 150.0
@export var swim_burst_rise_smoothing: float = 100.0
@export var swim_rise_decay_smoothing: float = 0.05
@export var swim_neutral_sink_speed: float = 1000.0
@export var swim_neutral_sink_smoothing: float = 0.1
@export var swim_burst_duration: float = 0.2
@export var swim_input_buffer_time: float = 0.35
@export var swim_down_speed: float = 140.0
@export var swim_down_lerp: float = 0.2
@export var swim_hold_lerp: float = 0.08
@export var swim_drift_speed: float = 20.0
@export var swim_drift_lerp: float = 0.1
@export var swim_turn_threshold: float = 10.0
@export var swim_slope_speed: float = 5.0
@export var swim_exit_boost: float = 2.5
@export var swim_exit_boost_cap: float = -300.0
@export var swim_spin_exit_delay: float = 0.6

@export_group("Death")
@export var death_z_index: int = 10
@export var death_camera_zoom: float = 2.0
@export var death_shake_strength: float = 40.0
@export var death_shake_time: float = 0.2
@export var death_fall_delay: float = 1.0
@export var death_transition_delay: float = 2.0
@export var death_screen_hold: float = 0.5

@export_group("Transitions")
@export var crouch_max_speed: float = 50.0
@export var move_input_threshold: float = 0.1
@export var walk_stop_speed: float = 0.5
@export var strike_grounded_frames: int = 5
@export var strike_exit_delay: float = 0.25

@export_group("FLUDD")
@export_subgroup("Hover")
@export var fludd_force: float = 200.0
@export var fludd_impulse: float = 1.3
@export var fludd_impulse_speed_cap: float = -500.0
@export var fludd_hover_min_rise_speed: float = -50.0
@export var fludd_lift_factor_min: float = 0.3
@export var fludd_lift_factor_max: float = 0.8
@export var fludd_lift_weight: float = 0.57
@export var fludd_fall_target_speed: float = -200.0
@export var fludd_fall_weight: float = 0.1
@export var fludd_launch_speed: float = -50.0
@export_subgroup("Speed Clamp")
@export var fludd_x_speed_cap: float = 120.0
@export var fludd_x_clamp_weight: float = 0.1
@export var fludd_x_clamp_rate: float = 20.0
@export_subgroup("Consumption")
@export var fludd_consume_rate: float = 1.0
@export var fludd_power_drain_rate: float = 45.0
@export var fludd_fuel_drain_ratio: float = 0.05
@export var fludd_switch_sfx_db: float = -10.0
@export_subgroup("Hover Dive")
@export var dive_fludd_force: float = 10.0
@export var dive_fludd_x_factor: float = 1.0
@export var dive_fludd_y_factor: float = 0.0
@export var dive_fludd_upward_bias: float = 0.0
@export var dive_fludd_dampen_y: float = 0.02
@export var dive_fludd_dampen_x: float = 0.03
@export_subgroup("Hover Floor Slide")
@export var slide_fludd_force: float = 50.0
@export var slide_fludd_x_factor: float = 1.0
@export var slide_fludd_y_factor: float = 0.0
@export var slide_fludd_upward_bias: float = 0.0
@export var slide_fludd_dampen_x: float = 0.03
@export_subgroup("Submerged")
@export var submerged_fludd_target_velocity: float = -1000.0
@export var submerged_fludd_ease_weight: float = 0.5
@export var submerged_fludd_ease_halflife: float = 0.3

@export_group("Internal")
@export var debug_container: Control
@export var floor_slope_raycast: RayCast2D
@export var spin_area: Area2D
@export var spin_shape: CollisionShape2D
@export var heal_particles: ParticleEmitter


@export var _input_handler: PlayerInputHandler
@export var _sprite_handler: PlayerSpriteHandler
@export var _fludd_handler: PlayerFluddHandler
@export var submerged_bus_effects: Array[AudioEffect]


var effective_midair_max_speed: float = 0.0
var _move_dir_raw: float = 0.0
var move_dir: float:
	get:
		return _move_dir_raw
	set(v):
		_move_dir_raw = v
var run_speed_percent: float = 0.0
var current_jump: int = 0
var slide_friction: float = 1.0
var jump_buffer_time: float = 0.15
var jump_buffer_timer: float = 0.0
var swim_buffer_time: float = 0.0

var is_dry: bool = true
var is_running: bool = false
var is_spinning: bool = false
var is_crouching: bool = false
var is_diving: bool = false
var is_falling: bool = false
var is_swimming: bool = false

var is_using_hover_fludd: bool = false

var is_input_jump: bool = false:
	get:
		if not can_jump or is_in_water(): 
			jump_buffer_timer = 0
			return false
		return jump_buffer_timer > 0.0
var is_input_dive: bool = false
var is_input_ground_pound: bool = false
var is_input_spin: bool = false
## How long a swim (jump-underwater) press stays buffered. Buffering it means the state machine
## still sees the press even if it samples on a frame after the one-frame "just pressed".
const SWIM_INPUT_BUFFER: float = 0.12
var swim_input_timer: float = 0.0
var is_input_swim: bool:
	get:
		return swim_input_timer > 0.0

var can_jump: bool = true
var can_spin: bool = false
var can_walk: bool = true
var can_dive: bool = true
var can_use_fludd: bool = true

var jump_chain_timer: float = 0.0
## lock the sprite flipping
@export var lock_flipping: bool = false

var cam: Camera2D


func _ready() -> void:
	effective_midair_max_speed = midair_max_speed
	var ingame_hud: IngameHUD = preload("uid://deyfsp6xn4e27").instantiate()
	ingame_hud.bind(self)
	add_child(ingame_hud)
	
	Level.get_camera().anchor_to_object(self)


func _process(delta: float) -> void:
	_move_dir_raw = Input.get_axis("move_left", "move_right")
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()
	is_input_dive = Input.is_action_pressed("dive") and not is_on_floor()
	is_input_ground_pound = Input.is_action_pressed("ground_pound")
	is_input_spin = Input.is_action_pressed("spin")

	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time if can_jump else 0.0
		swim_input_timer = SWIM_INPUT_BUFFER
	swim_input_timer = max(swim_input_timer - delta, 0.0)
	
	for action: String in BUFFER_ACTIONS:
		if Input.is_action_pressed(action):
			if buffer_dictionary.has(action):
				buffer_dictionary.set(action, buffer_dictionary.get(action, 0.0) + delta)
			else:
				buffer_dictionary.set(action, 0)
		elif Input.is_action_just_released(action):
			buffer_dictionary.erase(action)


func get_facing() -> int:
	return (-1 if sprite.flip_h else 1)


func get_facing_velocity() -> float:
	return velocity.x * get_facing()


func get_local_floor_normal() -> Vector2:
	var gc: GravityComponent = get_component(GravityComponent)
	return get_floor_normal().rotated(-gc.get_angle()) if gc else get_floor_normal()


func get_effective_friction() -> float:
	var friction_component: FrictionComponent = get_component(FrictionComponent)
	if friction_component:
		return friction_component.get_effective()
	return 1.0


func get_gravity_scale_factor() -> float:
	var gravity_component: GravityComponent = get_component(GravityComponent)
	if gravity_component:
		return gravity_component.scale_factor
	return 1.0


func get_gravity_relative_move_dir() -> float:
	var gc: GravityComponent = get_component(GravityComponent)
	if not gc:
		return move_dir
	var angle: float = gc.get_angle()
	var input_vec: Vector2 = Vector2(move_dir, 0.0).rotated(-angle)
	return input_vec.x


func get_input_handler() -> PlayerInputHandler:
	return _input_handler


func get_sprite_handler() -> PlayerSpriteHandler:
	return _sprite_handler


func get_fludd_handler() -> PlayerFluddHandler:
	return _fludd_handler


func is_state(state_name: StringName) -> bool:
	return machine.get_state_name() == state_name


func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


func is_action_just_pressed(action: String, buffer: float = 0.0) -> bool:
	if buffer > 0:
		if action in BUFFER_ACTIONS and buffer_dictionary.has(action):
			return buffer_dictionary.get(action) < buffer and Input.is_action_pressed(action)
	return Input.is_action_just_pressed(action)


func is_moving_with_facing() -> bool:
	return (sign(move_dir) == 1 and not sprite.flip_h) or (sign(move_dir) == -1 and sprite.flip_h)


func is_moving_against_facing() -> bool:
	return (sign(move_dir) == 1 and sprite.flip_h) or (sign(move_dir) == -1 and not sprite.flip_h)


func is_gravity_enabled() -> bool:
	var gravity_component: GravityComponent = get_component(GravityComponent)
	if gravity_component:
		return gravity_component.enabled
	return false


func set_gravity_enabled(enabled: bool) -> void:
	var gravity_component: GravityComponent = get_component(GravityComponent)
	if gravity_component:
		gravity_component.enabled = enabled


func set_gravity_scale_factor(scale_factor: float) -> void:
	var gravity_component: GravityComponent = get_component(GravityComponent)
	if gravity_component:
		gravity_component.scale_factor = scale_factor


func set_friction_scale_factor(scale_factor: float) -> void:
	var friction_component: FrictionComponent = get_component(FrictionComponent)
	if friction_component:
		friction_component.scale_factor = scale_factor


func add_power(amount: int) -> void:
	var health_component: HealthComponent = get_component(HealthComponent)
	health_component.power += amount


func add_fludd_power(amount: float) -> void:
	get_fludd_handler().fludd_power += amount


func resist(val: float, sub: float, div: float) -> float:
	var s: float = sign(val)
	val = max(0.0, abs(val) - sub)
	val /= div
	return val * s


func reset_jump_timer() -> void:
	jump_buffer_timer = 0


func get_terrain() -> String:
	if floor_slope_raycast.is_colliding():
		return floor_slope_raycast.get_collider().get_meta(&"terrain", "generic")
	
	return ""


func _on_water_check_water_entered() -> void:
	is_swimming = true
	swimming_changed.emit(true)
	for effect: AudioEffect in submerged_bus_effects:
		AudioServer.add_bus_effect(0, effect)


func _on_water_check_water_exited() -> void:
	is_swimming = false
	swimming_changed.emit(false)
	for i: int in submerged_bus_effects.size():
		AudioServer.remove_bus_effect(0, 0)
