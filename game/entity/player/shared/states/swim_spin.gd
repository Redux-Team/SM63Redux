@tool
extends State

@export var spin_hitbox: HitBox
## Time for which the spin hitbox is active, in seconds.
@export var spin_hitbox_timer: float = 0.3

func _on_enter() -> void:
	spin_hitbox.enable(spin_hitbox_timer)
	if not player.is_on_floor():
		if player.velocity.y > 0:
			player.velocity.y = -35
		else:
			player.velocity.y -= 50


func _on_physics_tick(_delta: float) -> void:
	if player.is_on_floor():
		player.lock_flipping = false
	if not Input.is_action_pressed("swim_down"):
		player.velocity.y = min(player.velocity.y, 0)


func _on_exit() -> void:
	spin_hitbox.disable()
