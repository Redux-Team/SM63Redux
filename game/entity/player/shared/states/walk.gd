extends PlayerState


var _footstep_frame: int = -1


func _enter() -> void:
	_footstep_frame = -1
	_apply_gait()


func _tick(_delta: float) -> void:
	_apply_gait()


func _render_tick(_delta: float) -> void:
	var frame: int = sprite.current_frame
	if frame == _footstep_frame:
		return
	
	_footstep_frame = frame
	var frames: PackedInt32Array = player.footstep_frames.get(sprite.current_animation, PackedInt32Array())
	if frames.has(frame):
		player.play_footstep()


func _apply_gait() -> void:
	var speed: float = absf(player.velocity.x)
	var wanted: StringName = &"run_loop" if speed >= player.run_animation_speed else &"walk_loop"
	if sprite.current_animation != wanted:
		sprite.play(wanted)
	
	if player.walk_speed_curve:
		var ratio: float = clampf(speed / maxf(player.run_max_speed, 1.0), 0.0, 1.0)
		sprite.speed_scale = player.walk_speed_curve.sample(ratio)


func _next() -> StringName:
	if not player.is_on_floor() and player.velocity.y >= 0.0:
		return &"Fall"
	if absf(player.move_dir) < player.move_input_threshold and absf(player.velocity.x) < player.walk_stop_speed:
		return &"Idle"
	if player.is_action_just_pressed("crouch") and player.is_on_floor():
		if absf(player.velocity.x) <= player.crouch_max_speed:
			return &"Crouch"
		if player.is_moving_with_facing():
			return &"Floorslide"
	if player.is_input_spin:
		return &"Spin"
	if player.is_on_floor() and player.is_action_just_pressed("jump", player.jump_buffer_window) and player.can_jump:
		return &"BaseJump"
	return &""
