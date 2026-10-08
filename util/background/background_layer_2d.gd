@tool
class_name BackgroundLayer2D
extends BackgroundLayer


enum AnchorPos {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
	CENTER,
	CUSTOM,
}

enum Edge {
	TOP,
	BOTTOM,
	LEFT,
	RIGHT,
}

enum Mirror {
	HORIZONTAL = 1,
	VERTICAL = 2,
}

enum StretchMode {
	NATIVE,
	FILL,
	FIT,
	COVER,
}

const MAX_QUADS: int = 16384

const ANCHOR_RATIOS: Dictionary[int, Vector2] = {
	AnchorPos.TOP: Vector2(0.5, 0.0),
	AnchorPos.BOTTOM: Vector2(0.5, 1.0),
	AnchorPos.LEFT: Vector2(0.0, 0.5),
	AnchorPos.RIGHT: Vector2(1.0, 0.5),
	AnchorPos.CENTER: Vector2(0.5, 0.5),
}

@export_group("Layer 2D")
@export_subgroup("Texture")
@export var texture: Texture2D:
	set(t): 
		texture = t
		emit_changed()
@export var stretch_mode: StretchMode = StretchMode.NATIVE:
	set(sm):
		stretch_mode = sm
		emit_changed()
@export var texture_scale: Vector2 = Vector2.ONE:
	set(ts):
		texture_scale = ts
		emit_changed()
@export var flip_h: bool = false:
	set(fh): 
		flip_h = fh
		emit_changed()
@export var flip_v: bool = false:
	set(fv):
		flip_v = fv
		emit_changed()

@export_subgroup("Placement")
@export var anchor: AnchorPos = AnchorPos.BOTTOM:
	set(a):
		anchor = a
		notify_property_list_changed()
		emit_changed()
@export var anchor_ratio: Vector2:
	set(ar):
		anchor_ratio = ar
		emit_changed()
@export var anchor_offset: Vector2:
	set(ao):
		anchor_offset = ao
		emit_changed()
@export_flags("Top", "Bottom", "Left", "Right") var edge_extend: int:
	set(ee):
		edge_extend = ee
		emit_changed()

@export_subgroup("Tiling")
@export var repeat_mode: RepeatMode = RepeatMode.INDEFINITE_X:
	set(rm):
		repeat_mode = rm
		notify_property_list_changed()
		emit_changed()
@export var repeat_amount: Vector2i = Vector2i(2, 0):
	set(ra):
		repeat_amount = ra
		emit_changed()
@export var spacing: Vector2:
	set(s):
		spacing = s
		emit_changed()
@export_flags("Horizontal", "Vertical") var mirror: int:
	set(m):
		mirror = m
		emit_changed()


func _build() -> Node:
	var parallax: Parallax2D = _build_parallax()
	if not texture:
		return parallax
	var grid: Vector2i = _get_grid()
	for iy: int in grid.y:
		for ix: int in grid.x:
			parallax.add_child(_build_sprite(ix, iy))
			for edge: int in Edge.size():
				if edge_extend & (1 << edge):
					parallax.add_child(_build_edge(ix, iy, edge))
	return parallax


func _update(node: Node, visible_rect: Rect2) -> void:
	var parallax: Parallax2D = node as Parallax2D
	if not parallax or not texture:
		return
	var grid: Vector2i = _get_grid()
	var draw_size: Vector2 = _get_draw_size(visible_rect.size)
	var tile: Vector2 = draw_size + spacing
	var period: Vector2 = (tile * Vector2(grid)).maxf(1.0)
	var repeat_size: Vector2 = _get_repeat_size(period)
	var repeat_times: int = _get_repeat_times(period, visible_rect.size)
	var origin: Vector2 = _get_origin(visible_rect.size, draw_size, period, repeat_size, repeat_times)
	var sprite_scale: Vector2 = draw_size / texture.get_size().maxf(1.0)
	var cursor: int = 0
	for iy: int in grid.y:
		for ix: int in grid.x:
			var cell: Vector2 = origin + tile * Vector2(ix, iy)
			var sprite: Sprite2D = parallax.get_child(cursor)
			sprite.position = cell
			sprite.scale = sprite_scale
			cursor += 1
			for edge: int in Edge.size():
				if edge_extend & (1 << edge):
					_fit_edge(parallax.get_child(cursor), edge, cell, visible_rect.size, draw_size)
					cursor += 1
	parallax.repeat_size = repeat_size
	parallax.repeat_times = repeat_times


func _build_sprite(ix: int, iy: int) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = texture
	sprite.centered = false
	sprite.flip_h = flip_h != (ix % 2 == 1)
	sprite.flip_v = flip_v != (iy % 2 == 1)
	return sprite


func _build_edge(ix: int, iy: int, edge: int) -> Sprite2D:
	var sprite: Sprite2D = _build_sprite(ix, iy)
	var size: Vector2 = texture.get_size()
	var last_x: float = size.x - 1.0
	var last_y: float = size.y - 1.0
	sprite.region_enabled = true
	match edge:
		Edge.TOP:
			sprite.region_rect = Rect2(0.0, last_y if sprite.flip_v else 0.0, size.x, 1.0)
		Edge.BOTTOM:
			sprite.region_rect = Rect2(0.0, 0.0 if sprite.flip_v else last_y, size.x, 1.0)
		Edge.LEFT:
			sprite.region_rect = Rect2(last_x if sprite.flip_h else 0.0, 0.0, 1.0, size.y)
		Edge.RIGHT:
			sprite.region_rect = Rect2(0.0 if sprite.flip_h else last_x, 0.0, 1.0, size.y)
	return sprite


func _fit_edge(sprite: Sprite2D, edge: int, cell: Vector2, visible_size: Vector2, draw_size: Vector2) -> void:
	var strip: Vector2 = draw_size / texture.get_size().maxf(1.0)
	match edge:
		Edge.TOP:
			sprite.position = cell - Vector2(0.0, visible_size.y)
			sprite.scale = Vector2(strip.x, visible_size.y)
		Edge.BOTTOM:
			sprite.position = cell + Vector2(0.0, draw_size.y)
			sprite.scale = Vector2(strip.x, visible_size.y)
		Edge.LEFT:
			sprite.position = cell - Vector2(visible_size.x, 0.0)
			sprite.scale = Vector2(visible_size.x, strip.y)
		Edge.RIGHT:
			sprite.position = cell + Vector2(draw_size.x, 0.0)
			sprite.scale = Vector2(visible_size.x, strip.y)


func _get_draw_size(visible_size: Vector2) -> Vector2:
	var size: Vector2 = texture.get_size().maxf(1.0)
	match stretch_mode:
		StretchMode.FILL:
			size = visible_size
		StretchMode.FIT:
			size *= minf(visible_size.x / size.x, visible_size.y / size.y)
		StretchMode.COVER:
			size *= maxf(visible_size.x / size.x, visible_size.y / size.y)
	return size * texture_scale


func _get_grid() -> Vector2i:
	return Vector2i(
		2 if mirror & Mirror.HORIZONTAL else 1,
		2 if mirror & Mirror.VERTICAL else 1
	)


func _get_custom_periods() -> Vector2i:
	var grid: Vector2i = _get_grid()
	return Vector2i(
		ceili(float(repeat_amount.x) / grid.x),
		ceili(float(repeat_amount.y) / grid.y)
	)


func _get_origin(visible_size: Vector2, draw_size: Vector2, period: Vector2, repeat_size: Vector2, repeat_times: int) -> Vector2:
	var ratio: Vector2 = ANCHOR_RATIOS.get(anchor, anchor_ratio)
	var origin: Vector2 = (visible_size - draw_size) * ratio + anchor_offset
	if repeat_mode == RepeatMode.CUSTOM:
		return origin
	var lead: int = repeat_times / 2
	if repeat_size.x > 0.0:
		origin.x = lead * period.x + fposmod(anchor_offset.x, period.x) - period.x
	if repeat_size.y > 0.0:
		origin.y = lead * period.y + fposmod(anchor_offset.y, period.y) - period.y
	return origin


func _get_repeat_size(period: Vector2) -> Vector2:
	match repeat_mode:
		RepeatMode.INDEFINITE_X:
			return Vector2(period.x, 0.0)
		RepeatMode.INDEFINITE_Y:
			return Vector2(0.0, period.y)
		RepeatMode.INDEFINITE_BOTH:
			return period
		RepeatMode.CUSTOM:
			var periods: Vector2i = _get_custom_periods()
			return Vector2(
				period.x if periods.x > 1 else 0.0,
				period.y if periods.y > 1 else 0.0
			)
	return Vector2.ZERO


func _get_repeat_times(period: Vector2, visible_size: Vector2) -> int:
	match repeat_mode:
		RepeatMode.INDEFINITE_X:
			return mini(ceili(visible_size.x / period.x) + 1, MAX_QUADS - 1)
		RepeatMode.INDEFINITE_Y:
			return mini(ceili(visible_size.y / period.y) + 1, MAX_QUADS - 1)
		RepeatMode.INDEFINITE_BOTH:
			var axes: int = maxi(ceili(visible_size.x / period.x), ceili(visible_size.y / period.y))
			return mini(axes + 1, floori(sqrt(MAX_QUADS)) - 1)
		RepeatMode.CUSTOM:
			var periods: Vector2i = _get_custom_periods()
			return maxi(1, maxi(periods.x, periods.y) - 1)
	return 1


func _validate_property(property: Dictionary) -> void:
	match property.name:
		&"anchor_ratio":
			if anchor != AnchorPos.CUSTOM:
				property.usage = PROPERTY_USAGE_NONE
		&"repeat_amount":
			if repeat_mode != RepeatMode.CUSTOM:
				property.usage = PROPERTY_USAGE_NONE
		&"spacing", &"mirror":
			if repeat_mode == RepeatMode.NONE:
				property.usage = PROPERTY_USAGE_NONE
