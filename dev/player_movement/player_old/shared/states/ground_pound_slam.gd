extends PlayerStateOld

@export var ground_pound_stars: AnimatedParticles
@export var ground_pound_dust: AnimatedParticles

var _exit_ready_at: float = -1.0


func _enter() -> void:
	ground_pound_dust.burst()
	ground_pound_stars.burst()
	player.velocity.x = 0
	player.lock_flipping = true
	player.can_jump = false
	_exit_ready_at = -1.0


func _exit() -> void:
	player.can_jump = true


func _next() -> StringName:
	if player.is_input_ground_pound and not player.is_on_floor():
		return &"GroundPoundFall"
	
	if _exit_ready_at < 0.0:
		if not player.is_in_water():
			_exit_ready_at = time
		return &""
	return &"Idle" if time - _exit_ready_at >= player.ground_pound_slam_exit_delay else &""
