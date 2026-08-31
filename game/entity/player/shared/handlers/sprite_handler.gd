class_name PlayerSpriteHandler
extends Node


@export_group("FLUDD")
@export var fludd_sprite: AnimatedSprite2D
@export var fludd_poses: FluddPoseSet
@export var fludd_needs_nozzle: bool = true
@export_group("Internal")
@export var _player: Player
@export var _doll: SmartSprite2D


var _fludd_origin: Vector2


func _ready() -> void:
	if fludd_sprite:
		_fludd_origin = fludd_sprite.position


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _player.move_dir != 0 and not _player.lock_flipping:
		_doll.flip_h = _player.move_dir < 0


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or not fludd_poses:
		return
	
	if not fludd_sprite:
		return
	
	var pose: FluddPose = fludd_poses.resolve(_doll.current_animation, _doll.current_frame)
	var equipped: bool = not fludd_needs_nozzle or _player.get_fludd_handler().equipped_nozzle != PlayerFluddHandler.FluddNozzle.NONE
	fludd_sprite.visible = pose != null and pose.visible and equipped
	if not fludd_sprite.visible:
		return
	
	var mirror: float = -1.0 if _doll.flip_h else 1.0
	fludd_sprite.frame = pose.frame
	fludd_sprite.flip_h = _doll.flip_h
	fludd_sprite.show_behind_parent = not pose.in_front
	fludd_sprite.position = Vector2((_fludd_origin.x + pose.offset.x) * mirror, _fludd_origin.y + pose.offset.y)
	fludd_sprite.rotation_degrees = pose.rotation_degrees * mirror
