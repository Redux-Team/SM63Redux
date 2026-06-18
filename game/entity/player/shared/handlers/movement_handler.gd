class_name PlayerMovementHandler
extends Node

@export_group("Movement Variables")

@export_subgroup("Grounded")
@export var walk_acceleration: float = 20.0
@export var turn_speed: float = 2.5
@export var damping_factor: float = 0.4
@export_subgroup("Airborne")
@export var air_resistance: float = 1.0
@export var midair_turn_speed: float = 1.0
@export var jump_strength: float = 360.0
@export var double_jump_strength: float = 460.0
@export var triple_jump_strength: float = 530.0
@export var jump_chain_time: float = 0.2
@export_subgroup("Submerged")
@export var water_resistance: float = 0.6
@export var swim_up_strength: float = 150.0
@export var water_sink_rate: float = 0.125
@export var water_drag_x: float = 1.001

@export_group("Speed Limits")
@export_subgroup("Dry")
@export var run_max_speed: float = 250.0
@export var terminal_velocity_x: float = 500.0
@export var terminal_velocity_y: float = 725.0
@export_subgroup("Submerged")
@export var spin_y_fall_rate: float = 0.0


var _floor_timeframe: Timeframe
var _air_timeframe: Timeframe


func get_elapsed_floor_time() -> Timeframe:
	return _floor_timeframe


func get_elapsed_air_time() -> Timeframe:
	return _air_timeframe
