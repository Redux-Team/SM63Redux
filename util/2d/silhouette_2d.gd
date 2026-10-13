class_name Silhouette2D
extends Node2D


@export var anchor: Node2D
@export var targets: Array[Sprite2D]
@export var canvas_size: Vector2i = Vector2i(128, 128)

var _viewport: SubViewport
var _canvas: RID


func _ready() -> void:
	_viewport = SubViewport.new()
	_viewport.transparent_bg = true
	_viewport.disable_3d = true
	_viewport.size = canvas_size
	_viewport.world_2d = World2D.new()
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)
	
	_canvas = RenderingServer.canvas_item_create()
	RenderingServer.canvas_item_set_parent(_canvas, _viewport.world_2d.canvas)
	RenderingServer.frame_pre_draw.connect(_redraw)
	
	process_physics_priority = 1
	_follow_anchor()
	reset_physics_interpolation()


func _exit_tree() -> void:
	RenderingServer.frame_pre_draw.disconnect(_redraw)
	RenderingServer.free_rid(_canvas)


func _physics_process(_delta: float) -> void:
	_follow_anchor()


func _follow_anchor() -> void:
	if anchor:
		global_transform = anchor.global_transform


func _draw() -> void:
	draw_texture(_viewport.get_texture(), -Vector2(canvas_size) / 2.0)


func _redraw() -> void:
	RenderingServer.canvas_item_clear(_canvas)
	var origin: Transform2D = Transform2D(0.0, Vector2(canvas_size) / 2.0) * get_global_transform().affine_inverse()
	for target: Sprite2D in targets:
		if not target or not target.texture or not target.is_visible_in_tree():
			continue
		
		RenderingServer.canvas_item_add_set_transform(_canvas, origin * target.get_global_transform())
		RenderingServer.canvas_item_add_texture_rect_region(_canvas, _destination_rect(target), target.texture.get_rid(), _source_rect(target))


func _source_rect(sprite: Sprite2D) -> Rect2:
	var full: Rect2 = sprite.region_rect if sprite.region_enabled else Rect2(Vector2.ZERO, sprite.texture.get_size())
	var size: Vector2 = full.size / Vector2(sprite.hframes, sprite.vframes)
	return Rect2(full.position + size * Vector2(sprite.frame_coords), size)


func _destination_rect(sprite: Sprite2D) -> Rect2:
	var rect: Rect2 = sprite.get_rect()
	var flip: Vector2 = Vector2(-1.0 if sprite.flip_h else 1.0, -1.0 if sprite.flip_v else 1.0)
	return Rect2(rect.position, rect.size * flip)
