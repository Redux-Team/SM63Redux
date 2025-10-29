class_name Player
extends Entity

signal entered_water
signal exited_water


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

@export_group("Speed Limits")
@export var run_max_speed: float = 250.0
@export var terminal_velocity_x: float = 500.0
@export var terminal_velocity_y: float = 725.0
@export_group("Internal")
@export var state_machine: StateMachine
@export var debug_container: Control
@export var floor_slope_raycast: RayCast2D


var move_dir: float = 0.0
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

var jump_chain_timer: float = 0.0
## lock the sprite flipping
@export var lock_flipping: bool = false


func _ready() -> void:
	Singleton.debug_mode_toggled.connect(_on_debug_toggle)


func _on_debug_toggle() -> void:
	debug_container.visible = Singleton.debug_mode
	debug_container.set_process(Singleton.debug_mode)


func _process(_delta: float) -> void:
	move_dir = Input.get_axis("move_left", "move_right")
	is_crouching = Input.is_action_pressed("crouch") and is_on_floor()
	is_input_dive = Input.is_action_just_pressed("dive") and not is_on_floor()
	is_input_ground_pound = Input.is_action_pressed("ground_pound")
	is_input_swim = Input.is_action_just_pressed("jump")
	is_input_spin = Input.is_action_pressed("spin")
	
	if Input.is_action_just_pressed("jump"):
		jump_buffer_timer = jump_buffer_time if can_jump else 0.0


func reset_jump_timer() -> void:
	jump_buffer_timer = 0
