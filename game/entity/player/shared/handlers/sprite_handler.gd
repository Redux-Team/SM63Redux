class_name PlayerSpriteHandler
extends Node

@export_group("Internal")
@export var _player: Player
@export var _doll: SmartSprite2D


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if _player.get_input_handler().get_x_axis() != 0 and not _player.lock_flipping:
		_doll.flip_h = _player.get_input_handler().get_x_axis() < 0
	
		#fludd_sprite_f.flip_h = doll.flip_h
		#fludd_sprite_b.flip_h = doll.flip_h
		#
		#if doll.flip_h:
			#fludd_sprite_f.offset.x = 6
			#fludd_sprite_b.offset.x = 8
		#else:
			#fludd_sprite_f.offset.x = 0
			#fludd_sprite_b.offset.x = 0
