extends PlayerState

@export var ground_pound_stars: AnimatedParticles
@export var ground_pound_dust: AnimatedParticles
@export var shake_delay_frames: int = 2

var _ready_at: float = -1.0
var _shake_pending: int = 0


func _enter() -> void:
	ground_pound_dust.burst()
	ground_pound_stars.burst()
	player.velocity.x = 0
	player.lock_flipping = true
	player.can_jump = false
	_ready_at = -1.0
	_shake_pending = shake_delay_frames


func _exit() -> void:
	player.can_jump = true


func _tick(_delta: float) -> void:
	if _shake_pending <= 0:
		return
	
	_shake_pending -= 1
	if _shake_pending <= 0 and player.is_on_floor():
		Level.get_camera().shake(18, 0.25)


func _next() -> StringName:
	if player.is_input_ground_pound and not player.is_on_floor():
		return &"GroundPoundFall"
	
	if _ready_at < 0.0:
		if not player.is_in_water():
			_ready_at = time
		return &""
	return &"Idle" if time - _ready_at >= player.gp_slam_exit_delay else &""
