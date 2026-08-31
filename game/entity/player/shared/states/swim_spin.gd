extends PlayerState


@export var spin_hitbox: HitBox


func _enter() -> void:
	spin_hitbox.enable(player.spin_hitbox_time)
	if not player.is_on_floor():
		if player.velocity.y > 0:
			player.velocity.y = player.spin_rise_from_fall
		else:
			player.velocity.y -= player.spin_rise_boost


func _tick(_delta: float) -> void:
	if player.is_on_floor():
		player.lock_flipping = false
	if not Input.is_action_pressed("swim_down"):
		player.velocity.y = min(player.velocity.y, 0)


func _exit() -> void:
	spin_hitbox.disable()


func _next() -> StringName:
	return &"SwimIdle" if not player.is_input_spin and time > player.swim_spin_exit_delay else &""
