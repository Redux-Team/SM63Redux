extends PlayerStateOld

@export var player_y_velocity_curve: Curve
@export var player_rotation_curve: Curve
@export var death_screen_texture: Texture2D
@export var transition_out_texture: Texture2D


func _enter() -> void:
	player.velocity = Vector2.ZERO
	sprite.lock_flipping = true
	await get_tree().create_timer(player.death_transition_delay).timeout
	(
		Singleton.build_screen_transition()
		.set_texture(death_screen_texture)
		.set_hold_duration(player.death_screen_hold)
		.set_swap(get_tree().reload_current_scene)
		.set_out_texture(transition_out_texture)
		.done()
	)


func _tick(_delta: float) -> void:
	player.velocity.y = player_y_velocity_curve.sample(time)
	player.sprite.local_rotation = -rad_to_deg(
		player_rotation_curve.sample(time)
	)
	player.move_and_slide()
