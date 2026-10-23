extends PlayerState

## Vertical velocity over time during the fall.
@export var velocity_curve: Curve
## Sprite rotation in radians over time during the fall.
@export var rotation_curve: Curve
@export_group("Transition")
## Time spent falling before the screen transition starts.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var transition_delay: float = 2.0
## Time the screen stays covered before the scene reloads.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var screen_hold: float = 0.5
## Mask shown while the screen is covered.
@export var screen_texture: Texture2D
## Mask used for the covering transition.
@export var out_texture: Texture2D


func _enter() -> void:
	player.velocity = Vector2.ZERO
	sprite.lock_flipping = true
	await get_tree().create_timer(transition_delay).timeout
	var transition: ScreenTransition.Builder = (
			Singleton.build_screen_transition()
			.set_texture(screen_texture)
			.set_out_texture(out_texture)
			.set_hold_duration(screen_hold)
			.set_swap(get_tree().reload_current_scene)
	)
	var level: Level = Level.of(player)
	if level:
		transition.load(level.dismantle)
	transition.done()


func _tick(_delta: float) -> void:
	player.velocity.y = velocity_curve.sample(time)
	sprite.local_rotation = -rad_to_deg(rotation_curve.sample(time))
	player.move_and_slide()
