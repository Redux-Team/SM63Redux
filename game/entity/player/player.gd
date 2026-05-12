# TODO - The player is in a relatively stable state; however, I do plan
# on reworking the API in the future, especially when it comes to class variables
# affecting states.
class_name Player
extends Entity

signal entered_water
signal exited_water

const BUFFER_ACTIONS: PackedStringArray = ["jump"]
var buffer_dictionary: Dictionary[String, float]

@export_group("Movement Variables")
@export_subgroup("Horizontal Movement")
@export var walk_acceleration: float = 20.0
@export var turn_speed: float = 2.5
@export var midair_turn_speed: float = 1.0
@export var air_resistance: float = 1.0
@export_subgroup("Vertical Movement")
@export var jump_strength: float = 360.0
@export var double_jump_strength: float = 460.0
@export var triple_jump_strength: float = 530.0
@export var jump_chain_time: float = 0.2
@export_subgroup("Underwater Movement")
@export var water_resistance: float = 0.6
@export var swim_up_strength: float = 150.0
@export var water_y_cap: float = 35.0
@export var water_sink_rate: float = 0.125
@export var water_drag_x: float = 1.001

@export_group("Speed Limits")
@export var run_max_speed: float = 250.0
@export var terminal_velocity_x: float = 500.0
@export var terminal_velocity_y: float = 725.0
@export_group("Internal")
@export var debug_container: Control
@export var floor_slope_raycast: RayCast2D
@export var spin_area: Area2D
@export var spin_shape: CollisionShape2D


@export var _input_handler: PlayerInputHandler
@export var _movement_handler: PlayerMovementHandler
@export var _sprite_handler: PlayerSpriteHandler



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

var is_in_water: bool = false:
	set(iiw):
		if iiw == is_in_water:
			return
		if iiw:
			entered_water.emit()
		else:
			exited_water.emit()
		is_in_water = iiw

var is_input_jump: bool = false:
	get:
		if not can_jump or is_in_water: 
			jump_buffer_timer = 0
			return false
		return jump_buffer_timer > 0.0
var is_input_dive: bool = false
var is_input_ground_pound: bool = false
var is_input_spin: bool = false
var is_input_swim: bool = false

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
	# TODO
	# fix gravity sprite flipping
	cam = Camera2D.new()
	cam.zoom = Vector2(1.2, 1.2)
	cam.position_smoothing_enabled = true
	cam.position_smoothing_speed = 10
	cam.ignore_rotation = false
	cam.rotation_smoothing_enabled = true
	
	add_child(cam)


func _process(delta: float) -> void:
	_move_dir_raw = Input.get_axis("move_left", "move_right")
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()
	is_input_dive = Input.is_action_pressed("dive") and not is_on_floor()
	is_input_ground_pound = Input.is_action_pressed("ground_pound")
	is_input_swim = Input.is_action_just_pressed("jump")
	is_input_spin = Input.is_action_pressed("spin")
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time if can_jump else 0.0
	
	for action: String in BUFFER_ACTIONS:
		if Input.is_action_pressed(action):
			if buffer_dictionary.has(action):
				buffer_dictionary.set(action, buffer_dictionary.get(action, 0.0) + delta)
			else:
				buffer_dictionary.set(action, 0)
		elif Input.is_action_just_released(action):
			buffer_dictionary.erase(action)
	
	
	if is_on_floor():
		if jump_chain_timer > 0.0:
			jump_chain_timer = max(jump_chain_timer - delta, 0.0)
			if jump_chain_timer == 0.0:
				current_jump = 0
		elif current_jump >= 3:
			current_jump = 0


func get_facing_velocity() -> float:
	return velocity.x * (-1.0 if sprite.flip_h else 1.0)


func get_active_state_uptime() -> float:
	return state_machine.get_current_state().get_elapsed_time()


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


func get_movement_handler() -> PlayerMovementHandler:
	return _movement_handler


func get_input_handler() -> PlayerInputHandler:
	return _input_handler


func get_sprite_handler() -> PlayerSpriteHandler:
	return _sprite_handler


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


func set_attached(object: Node2D, direction: String) -> void:
	state_machine.change_state("attached_%s" % direction)


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
