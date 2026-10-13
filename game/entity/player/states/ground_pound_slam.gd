extends PlayerState

@export var stars: AnimatedParticles
@export var dust: AnimatedParticles
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var recover_time: float = 0.3

var _settled_at: float = -1.0


func _enter() -> void:
	dust.burst()
	stars.burst()
	player.velocity.x = 0.0
	player.lock_flipping = true
	player.can_jump = false
	_settled_at = -1.0


func _exit() -> void:
	player.can_jump = true


func _next() -> StringName:
	if controls.is_held(&"ground_pound") and not player.is_on_floor():
		return &"GroundPoundFall"
	if _settled_at < 0.0:
		if not player.is_in_water():
			_settled_at = time
		return &""
	return &"Idle" if time - _settled_at >= recover_time else &""
