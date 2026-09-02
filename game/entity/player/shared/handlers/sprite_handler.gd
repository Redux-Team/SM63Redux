class_name PlayerSpriteHandler
extends Node


@export_group("FLUDD")
@export var fludd_sprite: SmartSprite2D
@export var fludd_nozzle_variants: Dictionary[int, StringName] = {
	PlayerFluddHandler.FluddNozzle.HOVER: &"hover",
	PlayerFluddHandler.FluddNozzle.ROCKET: &"rocket",
	PlayerFluddHandler.FluddNozzle.TURBO: &"turbo",
}
@export_subgroup("Plume", "plume_")
@export var plume_sprite: SmartSprite2D
@export var plume_animations: Dictionary[int, StringName] = {
	PlayerFluddHandler.FluddNozzle.HOVER: &"hover",
	PlayerFluddHandler.FluddNozzle.ROCKET: &"rocket",
	PlayerFluddHandler.FluddNozzle.TURBO: &"turbo",
}
@export var plume_offsets: Dictionary[int, Vector2]
## Kept on top of the plume sprite so the spray emits from wherever the plume is drawn.
@export var plume_particles: GPUParticles2D
@export_group("Internal")
@export var _player: Player
@export var _doll: SmartSprite2D


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	var fludd: PlayerFluddHandler = _player.get_fludd_handler()
	if not fludd:
		return
	
	fludd.fludd_nozzle_changed.connect(_on_fludd_nozzle_changed)
	_on_fludd_nozzle_changed(fludd.equipped_nozzle)


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _player.move_input != 0 and not _player.lock_flipping:
		_doll.flip_h = _player.move_input < 0
	
	_update_plume()


func _on_fludd_nozzle_changed(nozzle: PlayerFluddHandler.FluddNozzle) -> void:
	if not fludd_sprite:
		return
	
	var variant: StringName = fludd_nozzle_variants.get(nozzle, &"")
	fludd_sprite.follow_root = not variant.is_empty()
	fludd_sprite.visible = not variant.is_empty()
	fludd_sprite.follow_variant = variant
	
	if not plume_sprite:
		return
	
	var plume: StringName = plume_animations.get(nozzle, &"")
	if plume_sprite.has_animation(plume):
		plume_sprite.current_animation = plume
	plume_sprite.position = plume_offsets.get(nozzle, plume_sprite.position)


func _update_plume() -> void:
	if not plume_sprite:
		return
	
	if plume_particles:
		plume_particles.global_position = plume_sprite.global_position
	
	var fludd: PlayerFluddHandler = _player.get_fludd_handler()
	var spraying: bool = fludd != null and fludd.is_spraying()
	if plume_sprite.visible == spraying:
		return
	
	plume_sprite.visible = spraying
	plume_sprite.playing = spraying
	if spraying:
		plume_sprite.current_frame = 0
