extends PlayerState


var _dive_unlocked: bool = false


func _enter() -> void:
	player.velocity.x = clamp(player.velocity.x, -player.rollout_x_clamp, player.rollout_x_clamp)
	player.velocity.y = player.rollout_y_velocity
	player.can_dive = false
	_dive_unlocked = false


func _tick(_delta: float) -> void:
	if not _dive_unlocked and time >= player.rollout_dive_lock_time:
		_dive_unlocked = true
		player.can_dive = true


func _exit() -> void:
	player.can_dive = true


func _next() -> StringName:
	if player.is_on_floor() and time > player.rollout_idle_time:
		return &"Idle"
	if player.is_input_dive and time > player.rollout_dive_time and not player.is_on_floor() and player.can_dive:
		return &"Dive"
	if player.velocity.y > player.rollout_fall_min_speed and not player.is_on_floor() and time > player.rollout_fall_time \
	and player.is_action_pressed("use_fludd") and player.get_fludd_handler().equipped_nozzle != 0:
		return &"Fall"
	if player.is_input_spin and player.velocity.y > player.rollout_spin_min_speed:
		return &"Spin"
	return &""
