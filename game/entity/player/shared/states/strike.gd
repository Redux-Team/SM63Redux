extends PlayerState


const GROUNDED_MIN_FRAMES: int = 5
const EXIT_DELAY: float = 0.25

var _grounded_at: float = -1.0


func _enter() -> void:
	_grounded_at = -1.0


func _next() -> StringName:
	if _grounded_at < 0.0:
		if player.is_on_floor() and frames > GROUNDED_MIN_FRAMES:
			_grounded_at = time
		return &""
	return &"Idle" if time - _grounded_at >= EXIT_DELAY else &""
