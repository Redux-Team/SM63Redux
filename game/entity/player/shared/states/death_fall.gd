@tool
extends State

@export var player_y_velocity_curve: Curve
@export var player_rotation_curve: Curve
@export var death_screen_texture: Texture2D
@export var transition_out_texture: Texture2D


func _on_enter() -> void:
	player.velocity = Vector2.ZERO
	sprite.lock_flipping = true
	LevelCamera.get_instance().freeze()
	await get_tree().create_timer(2).timeout
	Singleton.build_screen_transition() \
		.set_texture(death_screen_texture) \
		.set_hold_duration(0.5) \
		.set_destination("uid://cf4yw3eqr2qo6") \
		.set_out_texture(transition_out_texture) \
		.done()


func _on_physics_tick(_delta: float) -> void:
	player.velocity.y = player_y_velocity_curve.sample(get_elapsed_time())
	player.sprite.local_rotation = -rad_to_deg(player_rotation_curve.sample(get_elapsed_time()))
	player.move_and_slide()
