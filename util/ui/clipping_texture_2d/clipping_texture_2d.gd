@tool
class_name ClippingTexture2D
extends Texture2D


@export var texture: Texture2D:
	set(v):
		if texture and texture.changed.is_connected(_on_texture_changed):
			texture.changed.disconnect(_on_texture_changed)
		texture = v
		if texture:
			texture.changed.connect(_on_texture_changed)
		emit_changed()

## Normalized anchor point the clip region grows FROM. (0,0) = top-left, (1,1) = bottom-right.
@export var clip_origin: Vector2 = Vector2.ZERO:
	set(v):
		clip_origin = v.clamp(Vector2.ZERO, Vector2.ONE)
		emit_changed()

## How much of the texture is revealed on each axis, in [0,1].
@export var clip_ratio: Vector2 = Vector2.ONE:
	set(v):
		clip_ratio = v.clamp(Vector2.ZERO, Vector2.ONE)
		emit_changed()


func _on_texture_changed() -> void:
	emit_changed()


func _get_width() -> int:
	return texture.get_width() if texture else 0


func _get_height() -> int:
	return texture.get_height() if texture else 0


func _get_clip_rect(display_size: Vector2) -> Rect2:
	var clipped_size: Vector2 = display_size * clip_ratio
	var origin: Vector2 = (display_size - clipped_size) * clip_origin
	return Rect2(origin, clipped_size)


func _draw(to_canvas_item: RID, pos: Vector2, modulate: Color, transpose: bool) -> void:
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	var clip: Rect2 = _get_clip_rect(tex_size)
	_draw_clipped(to_canvas_item, Rect2(pos + clip.position, clip.size), clip, modulate, transpose, false)


func _draw_rect(to_canvas_item: RID, rect: Rect2, _tile: bool, modulate: Color, transpose: bool) -> void:
	if texture == null:
		return
	var tex_size: Vector2 = texture.get_size()
	var clip: Rect2 = _get_clip_rect(rect.size)
	var uv_rect: Rect2 = Rect2(
		clip.position / rect.size * tex_size,
		clip.size / rect.size * tex_size
	)
	_draw_clipped(to_canvas_item, Rect2(rect.position + clip.position, clip.size), uv_rect, modulate, transpose, false)


func _draw_rect_region(to_canvas_item: RID, rect: Rect2, src_rect: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if texture == null:
		return
	var clip: Rect2 = _get_clip_rect(rect.size)
	var scale: Vector2 = src_rect.size / rect.size
	var uv_rect: Rect2 = Rect2(
		src_rect.position + clip.position * scale,
		clip.size * scale
	)
	_draw_clipped(to_canvas_item, Rect2(rect.position + clip.position, clip.size), uv_rect, modulate, transpose, clip_uv)


func _draw_clipped(to_canvas_item: RID, dest: Rect2, src: Rect2, modulate: Color, transpose: bool, clip_uv: bool) -> void:
	if texture is ScrollingTexture2D or texture is ClippingTexture2D:
		texture._draw_rect_region(to_canvas_item, dest, src, modulate, transpose, clip_uv)
	else:
		RenderingServer.canvas_item_add_texture_rect_region(
			to_canvas_item,
			dest,
			texture.get_rid(),
			src,
			modulate,
			transpose,
			clip_uv
		)
