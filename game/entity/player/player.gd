# TODO - The player is in a relatively stable state; however, I do plan
# on reworking the API in the future, especially when it comes to class variables
# affecting states.
class_name Player
extends Entity


signal swimming_changed(swimming: bool)


const BUFFERED_ACTIONS: PackedStringArray = ["jump"]
const FOOTSTEP_LAYER_FIRST: int = 25
## How long a swim (jump-underwater) press stays buffered. Buffering it means the state machine
## still sees the press even if it samples on a frame after the one-frame "just pressed".
const SWIM_INPUT_BUFFER_TIME: float = 0.12

@export_group("Movement")
@export_subgroup("Ground")
## Acceleration applied while walking forward.
@export var walk_acceleration: float = 20.0
## Factor to multiply acceleration by, while turning. 
@export var turn_acceleration_multiplier: float = 2.5
## Velocity to subtract while friction is being applied, every tick.
@export var ground_friction_flat: float = 0.3
## Divisor to divide velocity by while friction is being applied, every tick.
@export var ground_friction_divisor: float = 1.15
@export var slope_normal_threshold: float = 0.999
@export var slope_stick_speed: float = 0.5
## Friction applied when no inputs are pressed.
@export var dry_friction: float = 0.4
@export_subgroup("Air")
## Midair acceleration applied while holding forward.
@export var air_acceleration: float = 1.0
## Factor to multiply acceleration by.
@export var air_control_normal: float = 0.85
## Factor to multiply acceleration by, while spinning.
@export var air_control_spin: float = 0.35
## Factor to multiply acceleration by, while turning.
@export var air_turn_boost: float = 2.8
## Factor to multiply acceleration by, while turning and spinning.
@export var air_turn_boost_spin: float = 1.4
## Minimum horizontal velocity at which turning gives a higher acceleration.
@export var air_turn_speed_threshold: float = 10.0
## Factor to multiply acceleration by, while being over the midair max speed.
@export var air_over_speed_decel: float = 0.1
@export_subgroup("Underwater")
@export var water_resistance: float = 0.6
@export_subgroup("Limits")
## Maximum horizontal speed while walking.
@export var run_max_speed: float = 250.0
## Maximum horizontal speed while in midair.
@export var midair_max_speed: float = 190.0
## Absolute maximum horizontal speed.
@export var terminal_velocity_x: float = 500.0
## Absolute maximum vertical speed.
@export var terminal_velocity_y: float = 725.0

@export_group("Jump")
@export_subgroup("Strength")
## Upward velocity applied during a single jump.
@export var jump_strength: float = 340.0
## Upward velocity applied during a double jump.
@export var double_jump_strength: float = 420.0
## Upward velocity applied during a triple jump.
@export var triple_jump_strength: float = 500.0
## Minimum horizontal velocity required to perform a triple jump.
@export var triple_jump_min_speed: float = 120.0
@export_subgroup("Feel")
## Time taken for the jump chain to reset.
## You have to jump within this much time of landing
## to keep your single-double-triple jump chain.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var jump_chain_time: float = 0.15
## How much the jump height is multiplied by, 
## when tapping the jump button instead of holding it.
@export_range(0.0, 1.0) var jump_cut_multiplier: float = 0.75
## How long a jump can be buffered before touching the ground.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var jump_buffer_window: float = 0.2
@export_subgroup("Exits")
## idk dawg
@export var jump_spin_min_speed: float = -55.0
@export var fall_spin_min_speed: float = 100.0
@export var idle_jump_fall_speed: float = 50.0

@export_group("Dive")
@export_subgroup("Launch", "dive_")
## Average horizontal velocity while diving.
@export var dive_target_speed: float = 900.0
## How much time should be taken to reach the target speed.
@export var dive_time_to_target_speed: float = 0.058
## Upward velocity to add during dive launch.
@export var dive_launch_y_boost: float = 80.0
## Maximum vertical velocity when diving from an idle state.
@export var dive_neutral_launch_y_cap: float = -180.0
## Maximum vertical velocity during launch.
@export var dive_launch_y_min: float = -220.0
## Minimum vertical velocity during launch.
@export var dive_launch_y_max: float = 300.0
@export_subgroup("Ground Physics", "dive_")

## Velocity to subtract while diving on the ground, every tick. 
@export var dive_ground_flat_decel: float = 6.42
## Factor to subtract from velocity while diving on the ground, every tick.
@export var dive_ground_proportional_decel: float = 0.0196
## Friction multiplier during a dive landing.
@export var dive_landing_friction_multiplier: float = 2.0
## Maximum orizontal velocity required to remain in the dive slide state.
@export var dive_slide_stop_threshold: float = 30.0
@export_subgroup("Air Control", "dive_")
## How well the player can be controlled during a dive in midair, relative to walking.
@export var dive_air_control: float = 0.35
## Air resistance during a dive.
@export var dive_air_resistance: float = 0.0
## Factor to multiply acceleration by, while being over the dive midair max speed.
@export var dive_over_speed_decel: float = 3.0
@export_subgroup("Rotation", "dive_")
## How fast to rotate the sprite such that it matches the movement direction, while in midair.
@export_range(0.0, 1.0) var dive_air_rotation_blend: float = 0.2
## How fast to rotate the sprite such that it matches the floor incline, while grounded.
@export_range(0.0, 1.0) var dive_ground_rotation_blend: float = 0.15
## How fast to rotate the sprite such that it matches the floor incline, while grounded.
## Used when a "fast" rotation is requested.
@export_range(0.0, 1.0) var dive_ground_rotation_blend_fast: float = 0.3
@export var dive_landing_rotation_smooth_duration: float = 0.3
@export var dive_grounded_angle_deg: float = 90.0
@export var dive_rotation_min_deg: float = -60.0
@export var dive_rotation_max_deg: float = 85.0
## Unused.
@export var dive_rotation_curve: Curve
## Unused.
@export var dive_y_velocity_to_rotation_offset_curve: Curve
@export_subgroup("Recovery", "dive_")
@export var dive_slide_stop_duration: float = 0.133
@export var dive_reset_decel: float = 5.0

@export_group("Moves")
@export_subgroup("Floor Slide", "slide_")
## Sprite rotation angle while floorsliding.
@export var slide_flat_angle: float = 90.0
## Sprite rotation angle in degrees while nosediving.
@export var slide_max_nosedive_angle: float = 45.0
## How fast to rotate the sprite while floorsliding.
@export_range(0.0, 1.0) var slide_angle_lerp_speed: float = 0.5
## How fast to rotate the sprite while nosediving.
@export_range(0.0, 1.0) var slide_airborne_nosedive_speed: float = 0.15
## Time after leaving the ground, for which the player still uses floorsliding rotation.
@export var slide_ledge_buffer_time: float = 0.15
## Friction multiplier during a floorslide.
@export var slide_friction_scale: float = 1.6
## Additional gravity applied during a floorslide.
@export var slide_air_gravity_add: float = 1.0
## Divisor to divide terminal horizontal velocity by, during a floorslie.
@export var slide_terminal_x_divisor: float = 2.0
## Divisor to divide terminal vertical velocity by, during a floorslie.
@export var slide_terminal_y_divisor: float = 1.5
## Minimum speed required to remain in the floorslide state.
@export var slide_exit_speed: float = 5.0
## Minimum speed required to rollout of a slide.
@export var slide_rollout_min_speed: float = 50.0
@export_subgroup("Spin", "spin_")
## Gravity multiplier while spinning.
@export var spin_gravity_scale: float = 0.67
## Time for which the player does a "fast spin", being able to damage enemies.
@export var spin_fast_duration: float = 0.25
## Unused.
@export var spin_speed_scale_curve: Curve
## Time for which gravity is temporarily disabled, at the beginning of a spin.
@export var spin_gravity_resume_time: float = 0.1
## How long a spin lasts if the spin button is released.
@export var spin_duration: float = 0.5
## Vertical velocity applied when spinning while falling down.
@export var spin_rise_from_fall: float = -35.0
## Vertical velocity added when spinning while going up.
@export var spin_rise_boost: float = 50.0
## Maximum downward velocity while spinning.
@export var spin_fall_cap: float = 270.0
@export_subgroup("Backflip", "backflip_")
## Backward velocity added on backflip.
@export var backflip_x_boost: float = 280.0
## Upward velocity applied on backflip.
@export var backflip_y_velocity: float = -400.0
## Backward velocity added on backflip from a stationary position.
@export var backflip_up_x_boost: float = 50.0
## Upward velocity applied on backflip from a stationary position.
@export var backflip_up_y_velocity: float = -475.0
## Minimum downward velocity required to spin from a backflip.
@export var backflip_spin_min_speed: float = 155.0
@export_subgroup("Rollout", "rollout_")
## Horizontal speed is limited to this when beginning a rollout.
@export var rollout_x_clamp: float = 625.0
## Vertical velocity given when beginning a rollout.
@export var rollout_y_velocity: float = -200.0
## Time after a rollout after which the player can dive again.
@export var rollout_dive_lock_time: float = 0.275
## Time after a rollout after which the player is put in the idle state, if grounded.
@export var rollout_idle_time: float = 0.1
## Time after a rollout after which the player is put in the dive state, if diving.
@export var rollout_dive_time: float = 0.2
## Time after a rollout after which the player can use FLUDD to exit the rollout state.
@export var rollout_fall_time: float = 0.3
## Minimum downward velocity required to use FLUDD to exit the rollout state.
@export var rollout_fall_min_speed: float = 30.0
## Maximum upward velocity required to spin to exit the rollout state.
@export var rollout_spin_min_speed: float = -40.0
@export_subgroup("Stomp", "stomp_")
## Horizontal velocity reduction while stomping an enemy. 
## Velocity will not go lower than [member stomp_min_speed].
@export var stomp_drag: float = 900.0
## Minimum horizontal velocity while stomping an enemy.
@export var stomp_min_speed: float = 45.0
## How long the player stays in a stomping state, after jumping on an enemy.
@export var stomp_duration: float = 0.4
## Physics frames the feet hitbox stays live for, so one landing can squish everything under it.
@export var stomp_hitbox_frames: int = 2
## Vertical velocity applied during a stomp.
@export var stomp_bounce_speed: float = -280.0
@export_subgroup("Ground Pound", "ground_pound_")
## Speed at which the player rises in the somersault animation when beginning a ground pound.
@export var ground_pound_start_rise_speed: float = -38.0
## How long the start animation lasts.
@export var ground_pound_start_duration: float = 0.3
## Ground pound falling speed.
@export var ground_pound_fall_speed: float = 800.0
## How fast to reduce vertical velocity while in water.
@export_range(0.0, 1.0) var ground_pound_water_slow_lerp: float = 0.08
## Minimum downward velocity required to remain in the ground pound state while underwater.
@export var ground_pound_water_swim_speed: float = 50.0
## How much time the ground slam state lasts.
@export var ground_pound_slam_exit_delay: float = 0.3

@export_group("Swim")
@export_subgroup("Burst")
## Peak upward velocity applied during the swim burst (pixels/sec, positive = up in velocity space).
@export var swim_burst_rise_speed: float = 150.0
## How quickly velocity lerps toward the burst target each tick during the active burst window.
## Lower = smoother ramp-up, higher = snappier.
@export var swim_burst_rise_smoothing: float = 100.0
## How quickly upward velocity bleeds off toward neutral float after the burst ends.
## Lower = floatier tail, higher = quicker stop.
@export var swim_rise_decay_smoothing: float = 0.05
## How long the active burst window lasts before handing off descent control to Submerged.
@export var swim_burst_duration: float = 0.2
## How long the player's swim input is buffered after this state fires,
## preventing an immediate re-trigger from a held input.
@export var swim_input_buffer_time: float = 0.35
@export_subgroup("Drift")
## Neutral downward drift velocity while submerged and not actively swimming.
## Kept low so the player feels weightless rather than sinking.
@export var swim_neutral_sink_speed: float = 1000.0
## How quickly velocity lerps toward [member swim_neutral_sink_speed] once the burst has fully decayed.
@export_range(0.0, 1.0) var swim_neutral_sink_smoothing: float = 0.1
## Downward velocity while holding down.
@export var swim_down_speed: float = 140.0
## How quickly velocity lerps toward [member swim_down_speed] while holding down.
@export_range(0.0, 1.0) var swim_down_lerp: float = 0.2
## How quickly velocity lerps to 0 after pressing the swim button.
@export_range(0.0, 1.0) var swim_hold_lerp: float = 0.08
## Downward velocity while neither up nor down is pressed.
@export var swim_drift_speed: float = 20.0
## How quickly velocity lerps to [member swim_drift_speed] while neither up nor down is pressed.
@export_range(0.0, 1.0) var swim_drift_lerp: float = 0.1
@export_subgroup("Handling")
## Minimum velocity at which turning around is scaled by [member turn_acceleration_muliplier].
@export var swim_turn_threshold: float = 10.0
@export var swim_slope_speed: float = 5.0
@export var swim_spin_exit_delay: float = 0.6
@export_subgroup("Exit")
## Factor to multiply upward velocity by, when exiting the water, acting as a little boost.
@export var swim_exit_boost: float = 2.5
## Maximum upward velocity when exiting the water.
@export var swim_exit_boost_cap: float = -300.0

@export_group("Thresholds")
@export_subgroup("Movement")
## Maximum speed required to crouch while walking. 
## If over this speed, the player floorslides when the crouch button is pressed instead.
@export var crouch_max_speed: float = 50.0
## Deadzone for left/right movement.
@export var move_input_threshold: float = 0.1
## Horizontal speed at which the player stops walking and is considered to be idle.
@export var walk_stop_speed: float = 0.5
@export_subgroup("Animation")
## How much left/right needs to be held to use the run animation instead of the walk animation.
@export_range(0.0, 1.0, 0.01) var run_animation_input_threshold: float = 0.7
## If horizontal speed is lower than this, play the walk animation no matter the left/right input strength.
@export var walk_animation_stop_speed: float = 30.0
## The player sprite's [member SmartSprite2D.speed_scale] as a
## function of (movement speed / max. movement speed). 
@export var walk_speed_curve: Curve
@export_subgroup("Strike")
## If landed on the ground before these many frames elapse, 
## the player is not considered grounded for [member strike_exit_delay].
@export var strike_grounded_frames: int = 5
## After taking damage and landing on the ground, 
## time needed to recover into an idle state.
@export var strike_exit_delay: float = 0.25
## How long the swim strike state lasts. 
## The player recovers into the swimming idle state after this time.
@export var swim_strike_duration: float = 0.6

@export_group("Death")
@export_subgroup("Impact")
## Z index of the player on death.
@export var death_z_index: int = 10
## Camera zoom on death.
@export var death_camera_zoom: float = 2.0
## Strength of camera shake on death.
@export var death_shake_strength: float = 40.0
## Time to shake camera on death.
@export var death_shake_time: float = 0.2
@export_subgroup("Sequence")
## Time after death after which the player's falling sequence starts.
@export var death_fall_delay: float = 1.0
## Time after the death falling sequence, after which the screen transition starts.
@export var death_transition_delay: float = 2.0
## How long the screen transition lasts.
@export var death_screen_hold: float = 0.5

@export_group("FLUDD")
@export_subgroup("Hover", "fludd_")
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
@export var submerged_fludd_ease_halflife: float = 0.3

@export_group("Footsteps", "footstep_")
@export var footstep_bank: SFXBank
@export var footstep_particles: AnimatedParticles
@export var footstep_terrains: Array[StringName] = [&"grass", &"snow", &"cloud", &"ice", &"metal"]
@export var footstep_frames: Dictionary[StringName, PackedInt32Array] = {
	&"walk_loop": PackedInt32Array([0, 4]),
	&"run_loop": PackedInt32Array([0, 4]),
}

@export_group("Internal")
@export var floor_slope_raycast: RayCast2D
@export var heal_particles: ParticleEmitter
@export var submerged_bus_effects: Array[AudioEffect]
@export var _fludd_handler: PlayerFluddHandler
# lock the sprite flipping, used internally by many states
var lock_flipping: bool = false


var effective_midair_max_speed: float = 0.0
var move_input: float = 0.0
var jump_chain_index: int = 0
var jump_chain_timer: float = 0.0
var stomp_timer: float = 0.0
var swim_hold_timer: float = 0.0
var swim_input_timer: float = 0.0
var action_hold_times: Dictionary[String, float]

var is_spinning: bool = false
var is_crouching: bool = false
var is_diving: bool = false

var is_input_dive: bool = false
var is_input_ground_pound: bool = false
var is_input_spin: bool = false
var is_input_swim: bool:
	get:
		return swim_input_timer > 0.0

var can_jump: bool = true
var can_walk: bool = true
var can_dive: bool = true
var can_ground_pound: bool = true


func _ready() -> void:
	effective_midair_max_speed = midair_max_speed
	var ingame_hud: IngameHUD = preload("uid://deyfsp6xn4e27").instantiate()
	ingame_hud.bind(self)
	add_child(ingame_hud)
	
	Level.get_camera().anchor_to_object(self)


func _process(delta: float) -> void:
	move_input = Input.get_axis("move_left", "move_right")
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()
	is_input_dive = Input.is_action_pressed("dive") and not is_on_floor()
	is_input_ground_pound = Input.is_action_pressed("ground_pound")
	is_input_spin = Input.is_action_pressed("spin")
	
	if Input.is_action_just_pressed("jump"):
		swim_input_timer = SWIM_INPUT_BUFFER_TIME
	swim_input_timer = max(swim_input_timer - delta, 0.0)
	
	for action: String in BUFFERED_ACTIONS:
		if not Input.is_action_pressed(action):
			action_hold_times.erase(action)
		elif action_hold_times.has(action):
			action_hold_times.set(action, action_hold_times.get(action) + delta)
		else:
			action_hold_times.set(action, 0.0)


func get_facing() -> int:
	return (-1 if sprite.flip_h else 1)


func get_facing_velocity() -> float:
	return velocity.x * get_facing()


func get_local_floor_normal() -> Vector2:
	var gravity_component: GravityComponent = get_component(GravityComponent)
	return get_floor_normal().rotated(-gravity_component.get_angle()) if gravity_component else get_floor_normal()


func get_effective_friction() -> float:
	var friction_component: FrictionComponent = get_component(FrictionComponent)
	if friction_component:
		return friction_component.get_effective()
	return 1.0


func get_fludd_handler() -> PlayerFluddHandler:
	return _fludd_handler


func is_action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action)


func is_action_just_pressed(action: String, buffer: float = 0.0) -> bool:
	if buffer > 0:
		if action in BUFFERED_ACTIONS and action_hold_times.has(action):
			return action_hold_times.get(action) < buffer and Input.is_action_pressed(action)
	return Input.is_action_just_pressed(action)


func is_moving_with_facing() -> bool:
	return signf(move_input) == float(get_facing())


func is_moving_against_facing() -> bool:
	return signf(move_input) == float(-get_facing())


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


func request_pound_cancel() -> void:
	if is_input_ground_pound or not machine.is_active(&"GroundPound"):
		return
	
	machine.change_state(&"Fall")


func get_terrain() -> StringName:
	if not floor_slope_raycast.is_colliding():
		return &""
	
	var collider: CollisionObject2D = floor_slope_raycast.get_collider() as CollisionObject2D
	if not collider:
		return &""
	
	for i: int in footstep_terrains.size():
		if collider.get_collision_layer_value(FOOTSTEP_LAYER_FIRST + i):
			return footstep_terrains.get(i)
	
	return StringName(collider.get_meta(&"terrain", ""))


func get_debug_text() -> String:
	var debug_text: String = ""
	debug_text += "State: %s\n" % machine.get_state()
	debug_text += "Animation: %s\n" % sprite.current_animation
	debug_text += "Velocity: %s\n" % velocity
	
	return debug_text


func get_spin_speed_scale(elapsed: float) -> float:
	if not spin_speed_scale_curve:
		return 1.0
	
	var ratio: float = clampf(elapsed / maxf(spin_fast_duration, 0.001), 0.0, 1.0)
	return spin_speed_scale_curve.sample(lerpf(spin_speed_scale_curve.min_domain, spin_speed_scale_curve.max_domain, ratio))


func enter_slow_spin() -> void:
	var sprite_frames: SpriteFrames = sprite.diffuse_frames
	var current_fps: float = sprite.speed_scale * sprite_frames.get_animation_speed(sprite.current_animation)
	sprite.play_at_frame(&"spin_loop", sprite.current_frame)
	sprite.speed_scale = current_fps / maxf(sprite_frames.get_animation_speed(&"spin_loop"), 0.001)


func play_footstep() -> void:
	if footstep_bank:
		footstep_bank.play_sfx_at(global_position, footstep_bank.bank_group, self, sprite)
	if footstep_particles and abs(velocity.x) > 20:
		footstep_particles.burst()


func begin_stomp() -> void:
	stomp_timer = stomp_duration
	set_gravity_enabled(false)
	if velocity.y > 0.0:
		velocity.y = 0.0


func tick_stomp(delta: float) -> void:
	if stomp_timer <= 0.0:
		return
	
	stomp_timer -= delta
	if stomp_timer <= 0.0:
		stomp_timer = 0.0
		set_gravity_enabled(true)
		velocity.y = stomp_bounce_speed


func cancel_stomp() -> void:
	if stomp_timer <= 0.0:
		return
	
	stomp_timer = 0.0
	set_gravity_enabled(true)


func _on_feet_landed(_hurt_box: HurtBox) -> void:
	if velocity.y < 0.0 or stomp_timer > 0.0 or machine.is_active(&"GroundPound"):
		return
	
	if machine.is_active(&"Dive"):
		begin_stomp()
		return
	
	machine.change_state(&"Stomp")


func _on_water_check_water_entered() -> void:
	swimming_changed.emit(true)
	for effect: AudioEffect in submerged_bus_effects:
		AudioServer.add_bus_effect(0, effect)


func _on_water_check_water_exited() -> void:
	swimming_changed.emit(false)
	for i: int in submerged_bus_effects.size():
		AudioServer.remove_bus_effect(0, 0)
