class_name FluddVisuals
extends Node

## Backpack whose state is displayed.
@export var fludd: PlayerFludd
## Backpack sprite that follows the player's animation.
@export var fludd_sprite: SmartSprite2D
## Plume sprite shown while spraying.
@export var plume_sprite: SmartSprite2D
## Spray particles kept aligned with the plume.
@export var plume_particles: GPUParticles2D

var _plume_origin: Vector2 = Vector2.ZERO
var _default_animation: StringName = &""


func _ready() -> void:
	_plume_origin = plume_sprite.position
	_default_animation = fludd_sprite.follow_default
	fludd.nozzle_changed.connect(_on_nozzle_changed)
	_on_nozzle_changed(fludd.equipped_nozzle)


func _physics_process(_delta: float) -> void:
	var mode: FluddMode = fludd.get_selected_mode()
	var spraying: bool = fludd.is_spraying()
	_place_plume(mode)
	_animate_nozzle(mode, spraying)
	if plume_sprite.visible == spraying:
		return
	
	plume_sprite.visible = spraying
	plume_sprite.playing = spraying
	if spraying:
		plume_sprite.current_frame = 0


func _on_nozzle_changed(_nozzle: PlayerFludd.Nozzle) -> void:
	var mode: FluddMode = fludd.get_selected_mode()
	var variant: StringName = mode.fludd_variant if mode else &""
	var fludd_tween: Tween = create_tween()
	fludd_tween.tween_property(fludd_sprite, ^"offset:y", 3, 0.02)
	fludd_tween.tween_property(fludd_sprite, ^"offset:y", 0, 0.05)
	fludd_sprite.follow_root = not variant.is_empty()
	fludd_sprite.visible = not variant.is_empty()
	fludd_sprite.follow_variant = variant
	if mode and plume_sprite.has_animation(mode.plume_animation):
		plume_sprite.current_animation = mode.plume_animation


func _animate_nozzle(mode: FluddMode, spraying: bool) -> void:
	var using: bool = spraying and mode != null and not mode.use_animation.is_empty()
	var animation: StringName = (
			StringName("%s:%s" % [mode.fludd_variant, mode.use_animation])
			if using
			else _default_animation
	)
	if fludd_sprite.follow_default != animation:
		fludd_sprite.follow_default = animation
	
	if using:
		fludd_sprite.play(animation)
	elif fludd_sprite.playing:
		fludd_sprite.stop()


func _place_plume(mode: FluddMode) -> void:
	var facing: float = float(fludd.player.get_facing())
	var offset: Vector2 = mode.plume_offset if mode else Vector2.ZERO
	plume_sprite.position = \
			Vector2((_plume_origin.x + offset.x) * facing, _plume_origin.y + offset.y)
	var particle_offset: Vector2 = mode.particle_offset if mode else Vector2.ZERO
	plume_particles.global_position = \
			plume_sprite.global_position + Vector2(particle_offset.x * facing, particle_offset.y)
