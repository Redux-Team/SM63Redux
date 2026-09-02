class_name Bobomb
extends Entity

const FUSE_BOB_FRAMES: Array[int] = [1, 2, 5, 6]

@export var fuse: SmartSprite2D
@export var key: SmartSprite2D


func _ready() -> void:
	super()
	key.play()


func _on_sprite_frame_changed() -> void:
	fuse.offset = Vector2(0, 1) if sprite.current_frame in FUSE_BOB_FRAMES else Vector2.ZERO
	key.offset = fuse.offset
