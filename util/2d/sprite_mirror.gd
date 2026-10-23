class_name SpriteMirror
extends Sprite2D

@export var target: Sprite2D


func _ready() -> void:
	process_priority = 100
	process_physics_priority = 100
	_mirror()
	reset_physics_interpolation()


func _process(_delta: float) -> void:
	_mirror()


func _physics_process(_delta: float) -> void:
	_mirror()


func _mirror() -> void:
	if not is_instance_valid(target):
		return
	
	texture = target.texture
	centered = target.centered
	offset = target.offset
	flip_h = target.flip_h
	flip_v = target.flip_v
	hframes = target.hframes
	vframes = target.vframes
	frame = target.frame
	region_enabled = target.region_enabled
	region_rect = target.region_rect
	visible = target.is_visible_in_tree()
	var parent: CanvasItem = get_parent() as CanvasItem
	transform = (
			(parent.get_global_transform().affine_inverse() * target.get_global_transform())
			if parent
			else target.get_global_transform()
	)
