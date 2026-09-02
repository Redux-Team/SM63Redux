extends PlayerState

@export var ground_pound_stars: AnimatedParticles
@export var ground_pound_dust: AnimatedParticles

var _ready_at: float = -1.0


func _enter() -> void:
	Level.get_camera().shake(18, 0.25)
	ground_pound_dust.burst()
	ground_pound_stars.burst()
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
	return &"Idle" if time - _ready_at >= player.gp_slam_exit_delay else &""
