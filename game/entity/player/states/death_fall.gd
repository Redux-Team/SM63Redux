extends PlayerState

@export var velocity_curve: Curve
@export var rotation_curve: Curve
@export_group("Transition")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var transition_delay: float = 2.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var screen_hold: float = 0.5
@export var screen_texture: Texture2D
@export var out_texture: Texture2D


func _enter() -> void:
	player.velocity = Vector2.ZERO
	sprite.lock_flipping = true
	await get_tree().create_timer(transition_delay).timeout
	Singleton.build_screen_transition() \
		.set_texture(screen_texture) \
		.set_out_texture(out_texture) \
		.set_hold_duration(screen_hold) \
		.set_swap(get_tree().reload_current_scene) \
		.done()


func _tick(_delta: float) -> void:
	player.velocity.y = velocity_curve.sample(time)
	sprite.local_rotation = -rad_to_deg(rotation_curve.sample(time))
	player.move_and_slide()
