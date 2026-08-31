extends PlayerState


const GRAVITY_RESUME_TIME: float = 0.1
const SPIN_DURATION: float = 0.5

@export var spin_hitbox: HitBox

var _gravity_suspended: bool = false


func _enter() -> void:
	player.set_gravity_scale_factor(0.67)
	player.is_spinning = true
	spin_hitbox.enable(0.3)
	_gravity_suspended = false
	
	if not player.is_on_floor():
		player.set_gravity_enabled(false)
		_gravity_suspended = true
		if player.velocity.y > 0:
			player.velocity.y = -35
		else:
			player.velocity.y -= 50


func _tick(_delta: float) -> void:
	if _gravity_suspended and time >= GRAVITY_RESUME_TIME:
		_gravity_suspended = false
		player.set_gravity_enabled(true)
	
	if player.is_spinning and time >= SPIN_DURATION:
		player.is_spinning = false
	
	if player.is_on_floor():
		player.lock_flipping = false
	
	player.velocity.y = min(player.velocity.y, 270)


func _exit() -> void:
	player.set_gravity_enabled(true)
	player.set_gravity_scale_factor(1.0)
	spin_hitbox.disable()


func _next() -> StringName:
	if player.is_on_floor() and player.is_action_just_pressed("jump", 0.2):
		return &"BaseJump"
	if not player.is_input_spin and not player.is_spinning:
		return &"Idle" if player.is_on_floor() else &"Fall"
	if player.is_action_just_pressed("dive") and player.can_dive:
		return &"Dive"
	return &""
