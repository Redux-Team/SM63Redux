class_name Player 
extends Entity


@export_group("Movement Variables")
@export var gravity: float = 10.0
@export_group("Speed Limits")
@export var terminal_velocity_x: float = 80.0
@export var terminal_velocity_y: float = 20.0
@export_group("State Machine")
@export var state_machine: StateMachine


var move_dir: float = 0.0


func _physics_process(_delta: float) -> void:
	move_and_slide()
	
	move_dir = Input.get_axis("ui_left", "ui_right")
