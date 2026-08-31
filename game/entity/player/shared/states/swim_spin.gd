extends PlayerState


const EXIT_DELAY: float = 0.6

@export var spin_hitbox: HitBox


func _enter() -> void:
	spin_hitbox.enable(0.3)
	if not player.is_on_floor():
		if player.velocity.y > 0:
			player.velocity.y = -35
		else:
			player.velocity.y -= 50


func _tick(_delta: float) -> void:
	if player.is_on_floor():
		player.lock_flipping = false
	if not Input.is_action_pressed("swim_down"):
		player.velocity.y = min(player.velocity.y, 0)


func _exit() -> void:
	spin_hitbox.disable()


func _next() -> StringName:
	return &"SwimIdle" if not player.is_input_spin and time > EXIT_DELAY else &""
