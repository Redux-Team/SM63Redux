@tool
extends State

@export var spin_hitbox: HitBox

## Time for which the player is spinning, in seconds.
@export var spin_timer: float = 0.5
## Time for which the spin hitbox is active, in seconds.
@export var spin_hitbox_timer: float = 0.3

@export var gravity_scale_factor: float = 0.67
@export var gravity_disable_timer: float = 0.1
@export var terminal_velocity: float = 270

func _on_enter() -> void:
	player.set_gravity_scale_factor(gravity_scale_factor)
	player.is_spinning = true
	spin_hitbox.enable(spin_hitbox_timer)
	
	if not player.is_on_floor():
		player.set_gravity_enabled(false)
		if player.velocity.y > 0:
			player.velocity.y = -35
		else:
			player.velocity.y -= 50
		await get_tree().create_timer(gravity_disable_timer).timeout
		if is_active():
			player.set_gravity_enabled(true)
	
	await get_tree().create_timer(spin_timer).timeout
	if is_active():
		player.is_spinning = false


func _on_physics_tick(_delta: float) -> void:
	if player.is_on_floor():
		player.lock_flipping = false
	
	player.velocity.y = min(player.velocity.y, terminal_velocity)


func _on_exit() -> void:
	player.set_gravity_enabled(true)
	player.set_gravity_scale_factor(1.0)
	spin_hitbox.disable()
