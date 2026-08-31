extends PlayerState

@export var player_y_velocity_curve: Curve
@export var player_rotation_curve: Curve
@export var death_screen_texture: Texture2D
@export var transition_out_texture: Texture2D

const LEVEL_DESIGNER_SCENE: String = "uid://cf4yw3eqr2qo6"


func _enter() -> void:
	player.velocity = Vector2.ZERO
	sprite.lock_flipping = true
	LevelCamera.get_instance().freeze()
	await get_tree().create_timer(2).timeout
	Singleton.build_screen_transition() \
		.set_texture(death_screen_texture) \
		.set_hold_duration(0.5) \
		.set_swap(func() -> void: Singleton.get_editor_session().resume_or_open(get_tree(), LEVEL_DESIGNER_SCENE)) \
		.set_out_texture(transition_out_texture) \
		.done()


func _tick(_delta: float) -> void:
	player.velocity.y = player_y_velocity_curve.sample(time)
	player.sprite.local_rotation = -rad_to_deg(player_rotation_curve.sample(time))
	player.move_and_slide()
