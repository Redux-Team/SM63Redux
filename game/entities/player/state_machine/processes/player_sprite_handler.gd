@tool
extends StateProcess

@export var player_sprite: AnimatedSprite2D
@export var fludd_sprite_f: AnimatedSprite2D
@export var fludd_sprite_b: AnimatedSprite2D

## Sprite rotation, in degrees.
@export var sprite_rotation: float = 0.0:
	set(sr):
		player_sprite.rotation_degrees = -sr if player_sprite.flip_h else sr
		sprite_rotation = sr


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if player.move_dir != 0 and not player.lock_flipping:
		sprite.flip_h = player.move_dir < 0
	
		fludd_sprite_f.flip_h = sprite.flip_h
		fludd_sprite_b.flip_h = sprite.flip_h
		
		if sprite.flip_h:
			fludd_sprite_f.offset.x = 6
			fludd_sprite_b.offset.x = 8
		else:
			fludd_sprite_f.offset.x = 0
			fludd_sprite_b.offset.x = 0
