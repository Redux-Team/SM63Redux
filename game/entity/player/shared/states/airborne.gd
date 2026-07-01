@tool
extends State

@export var accel_multiplier: float = 0.85
@export var accel_multiplier_spin: float = 0.35
@export var turn_speed_multiplier: float = 2.8
@export var turn_speed_multiplier_spin: float = 1.4


func _on_physics_tick(_delta: float) -> void:
	if abs(player.move_dir) > 0 and not player.is_diving:
		air_move(player.move_dir)
	
	player.velocity.y = min(player.velocity.y, player.terminal_velocity_y)


func air_move(move_dir: float) -> void:
	var accel: float = player.midair_turn_speed
	var max_speed: float = player.effective_midair_max_speed
	var is_spinning: bool = state_machine.get_current_state().get_internal_name() == "spin"
	var accel_mult: float = accel_multiplier_spin if is_spinning and not player.is_on_floor() else accel_multiplier
	
	if sign(player.velocity.x) != sign(move_dir) and abs(player.velocity.x) > 10.0:
		accel_mult = turn_speed_multiplier_spin if is_spinning else turn_speed_multiplier
	
	var vx: float = player.velocity.x
	
	if abs(vx) < max_speed or sign(vx) != sign(move_dir):
		vx = move_toward(vx, max_speed * move_dir, accel * accel_mult)
	elif abs(vx) > max_speed and not player.get_fludd_handler().is_hover_active():
		vx = move_toward(vx, max_speed * sign(vx), accel * accel_mult * 0.1)
	
	player.velocity.x = vx
