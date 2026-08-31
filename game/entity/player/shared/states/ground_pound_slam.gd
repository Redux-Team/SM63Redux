extends PlayerState


const EXIT_DELAY: float = 0.3

var _ready_at: float = -1.0


func _enter() -> void:
	player.velocity.x = 0
	player.lock_flipping = true
	player.can_jump = false
	_ready_at = -1.0


func _exit() -> void:
	player.can_jump = true


func _next() -> StringName:
	if _ready_at < 0.0:
		if not player.is_in_water():
			_ready_at = time
		return &""
	return &"Idle" if time - _ready_at >= EXIT_DELAY else &""
