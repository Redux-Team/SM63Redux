class_name PlayerSpriteHandler
extends Node


@export_group("FLUDD")
@export var fludd_sprite: SmartSprite2D
@export var fludd_nozzle_variants: Dictionary[int, StringName] = {
	PlayerFluddHandler.FluddNozzle.HOVER: &"hover",
	PlayerFluddHandler.FluddNozzle.ROCKET: &"rocket",
	PlayerFluddHandler.FluddNozzle.TURBO: &"turbo",
}
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
	
	if _player.move_dir != 0 and not _player.lock_flipping:
		_doll.flip_h = _player.move_dir < 0


func _on_fludd_nozzle_changed(nozzle: PlayerFluddHandler.FluddNozzle) -> void:
	if not fludd_sprite:
		return
	
	var variant: StringName = fludd_nozzle_variants.get(nozzle, &"")
	fludd_sprite.follow_root = not variant.is_empty()
	fludd_sprite.visible = not variant.is_empty()
	fludd_sprite.follow_variant = variant
