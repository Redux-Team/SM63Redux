class_name PlayerSpriteHandler
extends Node


@export_group("FLUDD")
@export var fludd_sprite: SmartSprite2D
## Kept on top of the plume sprite so the spray emits from wherever the plume is drawn.
@export var plume_sprite: SmartSprite2D
@export var plume_particles: GPUParticles2D
@export_group("Internal")
@export var _player: Player
@export var _doll: SmartSprite2D


var _plume_base_position: Vector2 = Vector2.ZERO
var _fludd_base_default: StringName = &""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	if plume_sprite:
		_plume_base_position = plume_sprite.position
	if fludd_sprite:
		_fludd_base_default = fludd_sprite.follow_default
	
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


func _on_fludd_nozzle_changed(_nozzle: PlayerFluddHandler.FluddNozzle) -> void:
	if not fludd_sprite:
		return
	
	var mode: FluddMode = _player.get_fludd_handler().get_selected_mode()
	var variant: StringName = mode.fludd_variant if mode else &""
	fludd_sprite.follow_root = not variant.is_empty()
	fludd_sprite.visible = not variant.is_empty()
	fludd_sprite.follow_variant = variant
	
	if not plume_sprite or not mode:
		return
	
	if plume_sprite.has_animation(mode.plume_animation):
		plume_sprite.current_animation = mode.plume_animation


func _update_plume() -> void:
	if not plume_sprite:
		return
	
	var fludd: PlayerFluddHandler = _player.get_fludd_handler()
	_apply_plume_offsets(fludd)
	
	var spraying: bool = fludd != null and fludd.is_spraying()
	_apply_nozzle_animation(fludd, spraying)
	if plume_sprite.visible == spraying:
		return
	
	plume_sprite.visible = spraying
	plume_sprite.playing = spraying
	if spraying:
		plume_sprite.current_frame = 0


func _apply_nozzle_animation(fludd: PlayerFluddHandler, spraying: bool) -> void:
	if not fludd_sprite:
		return
	
	var mode: FluddMode = fludd.get_selected_mode() if fludd else null
	var using: bool = spraying and mode != null and not mode.use_animation.is_empty()
	var wanted: StringName = StringName("%s:%s" % [mode.fludd_variant, mode.use_animation]) if using else _fludd_base_default
	
	if fludd_sprite.follow_default != wanted:
		fludd_sprite.follow_default = wanted
	
	if using:
		fludd_sprite.play(wanted)
	elif fludd_sprite.playing:
		fludd_sprite.stop()


func _apply_plume_offsets(fludd: PlayerFluddHandler) -> void:
	var mode: FluddMode = fludd.get_selected_mode() if fludd else null
	var facing: float = float(_player.get_facing())
	var offset: Vector2 = mode.plume_offset if mode else Vector2.ZERO
	
	plume_sprite.position = Vector2((_plume_base_position.x + offset.x) * facing, _plume_base_position.y + offset.y)
	
	if not plume_particles:
		return
	
	var particle_offset: Vector2 = mode.particle_offset if mode else Vector2.ZERO
	plume_particles.global_position = plume_sprite.global_position + Vector2(particle_offset.x * facing, particle_offset.y)
