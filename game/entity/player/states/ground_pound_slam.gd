extends PlayerState

## Star burst emitted on impact.
@export var stars: AnimatedParticles
## Dust burst emitted on impact.
@export var dust: AnimatedParticles
## Time spent recovering after the slam before returning to idle.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var recover_time: float = 0.3
@export var shake_delay_frames: int = 2
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var shake_strength: float = 2.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var shake_duration: float = 0.25

var _settled_at: float = -1.0
var _shake_countdown: int = 0


func _enter() -> void:
	dust.burst()
	stars.burst()
	player.velocity.x = 0.0
	player.lock_flipping = true
	player.can_jump = false
	_settled_at = -1.0
	_shake_countdown = shake_delay_frames


func _tick(_delta: float) -> void:
	if _shake_countdown <= 0:
		return
	
	_shake_countdown -= 1
	var level: Level = Level.of(player)
	if _shake_countdown <= 0 and player.is_on_floor() and level:
		level.camera.shake(
				shake_strength * player.get_attribute_scale(&"shake_scale"),
				shake_duration,
		)


func _exit() -> void:
	player.can_jump = true


func _next() -> StringName:
	if controls.is_held(&"ground_pound") and not player.is_on_floor():
		return &"GroundPoundFall"
	if player.is_swimming():
		return &"SwimIdle"
	if _settled_at < 0.0:
		_settled_at = time
		return &""
	return &"Idle" if time - _settled_at >= recover_time else &""
