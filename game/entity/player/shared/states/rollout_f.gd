extends PlayerState


const DIVE_LOCK_TIME: float = 0.275

var _dive_unlocked: bool = false


func _enter() -> void:
	player.velocity.x = clamp(player.velocity.x, -625, 625)
	player.velocity.y = -200
	player.can_dive = false
	_dive_unlocked = false


func _tick(_delta: float) -> void:
	if not _dive_unlocked and time >= DIVE_LOCK_TIME:
		_dive_unlocked = true
		player.can_dive = true


func _exit() -> void:
	player.can_dive = true


func _next() -> StringName:
	if player.is_on_floor() and time > 0.1:
		return &"Idle"
	if player.is_input_dive and time > 0.2 and not player.is_on_floor() and player.can_dive:
		return &"Dive"
	if player.velocity.y > 30.0 and not player.is_on_floor() and time > 0.3 \
	and player.is_action_pressed("use_fludd") and player.get_fludd_handler().equipped_nozzle != 0:
		return &"Fall"
	if player.is_input_spin and player.velocity.y > -40.0:
		return &"Spin"
	return &""
