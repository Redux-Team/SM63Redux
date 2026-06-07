@tool
class_name ScrollingTexture2D
extends Texture2D


@export var texture: Texture2D:
	set(v):
		if texture and texture.changed.is_connected(_on_texture_changed):
			texture.changed.disconnect(_on_texture_changed)
		texture = v
		if texture:
			texture.changed.connect(_on_texture_changed)
		emit_changed()

@export var scroll: Vector2 = Vector2.ZERO:
	set(v):
		scroll = v
		emit_changed()


func _on_texture_changed() -> void:
	emit_changed()


func _get_width() -> int:
	return texture.get_width() if texture else 0


func _get_height() -> int:
	return texture.get_height() if texture else 0


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	_draw_scrolled(to_canvas_item, Rect2(pos, tex_size), Rect2(scroll * tex_size, tex_size), modulate, transpose)


func _draw_rect(to_canvas_item: RID, rect: Rect2, _tile: bool, modulate: Color, transpose: bool) -> void:
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	_draw_scrolled(to_canvas_item, rect, Rect2(scroll * tex_size, tex_size), modulate, transpose)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	_draw_scrolled(to_canvas_item, rect, Rect2(src_rect.position + scroll * tex_size, src_rect.size), modulate, transpose)


func _draw_scrolled(to_canvas_item: RID, dest: Rect2, src: Rect2, modulate: Color, transpose: bool) -> void:
	if texture is ScrollingTexture2D or texture is ClippingTexture2D:
		texture._draw_rect_region(to_canvas_item, dest, src, modulate, transpose, true)
	else:
		RenderingServer.canvas_item_add_texture_rect_region(
			to_canvas_item,
			dest,
			texture.get_rid(),
			src,
			modulate,
			transpose,
			true
		)
