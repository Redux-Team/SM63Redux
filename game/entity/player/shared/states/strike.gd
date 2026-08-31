extends PlayerState


var _grounded_at: float = -1.0


func _enter() -> void:
	_grounded_at = -1.0


func _next() -> StringName:
	if _grounded_at < 0.0:
		if player.is_on_floor() and frames > player.strike_grounded_frames:
			_grounded_at = time
		return &""
	return &"Idle" if time - _grounded_at >= player.strike_exit_delay else &""
