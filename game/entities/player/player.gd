class_name Player 
extends Entity


@export_group("Movement Variables")
@export_subgroup("Horizontal Movement")
@export var turn_speed: float = 1.5
@export_subgroup("Vertical Movement")
@export var jump_curve: Curve
@export var double_jump_curve: Curve
@export var triple_jump_curve: Curve
@export var min_jump_time: float = 0.3
@export var max_jump_time: float = 0.7
@export var gravity: float = 10.0

@export_group("Curves")
@export_subgroup("Run")
@export var run_speedup: Curve
@export var run_slowdown: Curve

@export_group("Speed Limits")
@export var run_max_speed: float = 250.0
@export var terminal_velocity_x: float = 500.0
@export var terminal_velocity_y: float = 725.0
@export_group("State Machine")
@export var state_machine: StateMachine


var move_dir: float = 0.0

var is_running: bool = false
var is_jumping: bool = false

var disable_gravity: bool = false



func _physics_process(_delta: float) -> void:
	move_and_slide()
	
	move_dir = Input.get_axis(&"move_left", &"move_right")
