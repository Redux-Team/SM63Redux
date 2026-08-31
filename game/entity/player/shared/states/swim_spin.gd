extends PlayerState


@export var spin_hitbox: HitBox

var _slowed: bool = false


func _enter() -> void:
	_slowed = false
	spin_hitbox.enable(player.spin_fast_duration)
	if not player.is_on_floor():
		if player.velocity.y > 0:
			player.velocity.y = player.spin_rise_from_fall
		else:
			player.velocity.y -= player.spin_rise_boost


func _tick(_delta: float) -> void:
	if not _slowed and time >= player.spin_fast_duration:
		_slowed = true
		sprite.play_at_frame(&"spin_loop", sprite.current_frame)
	
	if player.is_on_floor():
		player.lock_flipping = false
	if not Input.is_action_pressed("swim_down"):
		player.velocity.y = min(player.velocity.y, 0)


func _exit() -> void:
	spin_hitbox.disable()


func _next() -> StringName:
	return &"SwimIdle" if not player.is_input_spin and time > player.swim_spin_exit_delay else &""
