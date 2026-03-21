@tool
class_name LDObjectPolygon
extends LDObject


@export var base_texture: Texture2D:
	set(t):
		base_texture = t
		_update_visuals()

@export_group("Topline", "topline")
@export var topline_texture: Texture2D:
	set(t):
		topline_texture = t
		_update_visuals()
@export var topline_shadow_texture: Texture2D:
	set(t):
		topline_shadow_texture = t
		_update_visuals()
@export var topline_left_end: Texture2D:
	set(t):
		topline_left_end = t
		_update_visuals()
@export var topline_right_end: Texture2D:
	set(t):
		topline_right_end = t
		_update_visuals()
## Minimum dot product with Vector2.UP for an edge to be considered a topline edge.
## 0.0 = any upward-facing edge, 1.0 = only perfectly flat edges.
@export_range(-1.0, 1.0, 0.01) var topline_angle_threshold: float = 0.55:
	set(v):
		topline_angle_threshold = v
		_update_visuals()

@export_range(0.1, 128.0, 0.1) var topline_width: float = 26.0:
	set(v):
		topline_width = v
		_update_visuals()

@export_group("Outline", "outline")
@export var outline_texture: Texture2D:
	set(t):
		outline_texture = t
		_update_visuals()
@export var outline_width: float = 10.0:
	set(v):
		outline_width = v
		_update_visuals()

@export_group("Display")
@export var border_width: float = 3.0:
	set(v):
		border_width = v
		queue_redraw()

@export_group("Internal")
@export var _polygon: Polygon2D
@export var _topline_container: Node2D
@export var _topline_shadow_container: Node2D
@export var _outline: Line2D

@export_group("Editor Props")
@export var editor_polygon: CollisionPolygon2D

@export_tool_button("Create Polygon Props") var _create_polygon_props: Callable:
	get: return func() -> void:
		if not _polygon:
			_polygon = Polygon2D.new()
			_polygon.name = "Polygon"
			_polygon.color = Color.TRANSPARENT
			_polygon.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			add_child(_polygon)
			_polygon.owner = self
		
		if not _topline_container:
			_topline_container = Node2D.new()
			_topline_container.name = "ToplineContainer"
			add_child(_topline_container)
			_topline_container.owner = self
		
		if not _topline_shadow_container:
			_topline_shadow_container = Node2D.new()
			_topline_shadow_container.name = "ToplineShadowContainer"
			_polygon.add_child(_topline_shadow_container)
			_topline_shadow_container.owner = self
		
		if not _outline:
			_outline = Line2D.new()
			_outline.name = "Outline"
			_outline.width = outline_width
			add_child(_outline)
			_outline.owner = self
			_setup_line2d(_outline)
		
		if not editor_shape_area:
			editor_shape_area = Area2D.new()
			editor_shape_area.name = "EditorShapeArea"
			add_child(editor_shape_area)
			editor_shape_area.owner = self
			
			var col_poly: CollisionPolygon2D = CollisionPolygon2D.new()
			col_poly.name = "EditorPolygon"
			editor_shape_area.add_child(col_poly)
			col_poly.owner = self
			editor_polygon = col_poly
		
		if not origin_marker:
			origin_marker = Marker2D.new()
			origin_marker.name = "Origin"
			add_child(origin_marker)
			origin_marker.owner = self


var _selection_state: LDObject.SelectionState = LDObject.SelectionState.HIDDEN


func _on_preview() -> void:
	modulate = Color(1.0, 1.0, 1.0, 0.6)


func _on_place() -> void:
	modulate = Color.WHITE


func set_selection_state(state: LDObject.SelectionState) -> void:
	_selection_state = state
	queue_redraw()


func get_stamp_size() -> Vector2:
	if not _polygon or _polygon.polygon.is_empty():
		return Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
	return _get_polygon_bounds().size


func apply_points(points: PackedVector2Array) -> void:
	if _polygon:
		_polygon.polygon = points
		_polygon.color = Color.TRANSPARENT
	if editor_polygon:
		editor_polygon.polygon = points
	_update_visuals()
	queue_redraw()


func _update_visuals() -> void:
	if not is_node_ready():
		return
	
	if _polygon:
		_polygon.texture = base_texture
		_polygon.color = Color.WHITE if base_texture else Color.TRANSPARENT
	
	if not _polygon or _polygon.polygon.size() < 3:
		if _topline_container:
			for child: Node in _topline_container.get_children():
				child.queue_free()
		if _topline_shadow_container:
			for child: Node in _topline_shadow_container.get_children():
				child.queue_free()
		if _outline:
			_outline.points = PackedVector2Array()
		return
	
	var points: PackedVector2Array = _ensure_clockwise(_polygon.polygon)
	var closed_points: PackedVector2Array = _get_closed_points(points)
	var top_segments: Array[PackedVector2Array] = _get_topline_segments(points)
	
	if _topline_container:
		for child: Node in _topline_container.get_children():
			child.queue_free()
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			_setup_line2d(line)
			line.width = topline_width
			line.texture = topline_texture
			line.points = _subdivide_for_line2d(segment, topline_texture)
			_topline_container.add_child(line)
	
	if _topline_shadow_container:
		for child: Node in _topline_shadow_container.get_children():
			child.queue_free()
		for segment: PackedVector2Array in top_segments:
			var line: Line2D = Line2D.new()
			_setup_line2d(line)
			line.width = topline_width + (topline_width / 3.0)
			line.texture = topline_shadow_texture
			line.default_color = Color(1.0, 1.0, 1.0, 0.6)
			line.points = _subdivide_for_line2d(segment, topline_shadow_texture)
			_topline_shadow_container.add_child(line)
	
	if _outline:
		_setup_line2d(_outline)
		_outline.width = outline_width
		_outline.texture = outline_texture
		_outline.points = _subdivide_for_line2d(closed_points, outline_texture)


func _ensure_clockwise(points: PackedVector2Array) -> PackedVector2Array:
	var area: float = 0.0
	var count: int = points.size()
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		area += (b.x - a.x) * (b.y + a.y)
	if area < 0.0:
		return points
	var reversed: PackedVector2Array = PackedVector2Array()
	for i: int in range(count - 1, -1, -1):
		reversed.append(points[i])
	return reversed


func _get_topline_segments(points: PackedVector2Array) -> Array[PackedVector2Array]:
	var count: int = points.size()
	var segments: Array[PackedVector2Array] = []
	var current: PackedVector2Array = PackedVector2Array()
	
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		var edge: Vector2 = (b - a).normalized()
		var normal: Vector2 = Vector2(edge.y, -edge.x)
		if normal.y < -topline_angle_threshold:
			if current.is_empty():
				current.append(a)
			current.append(b)
		else:
			if not current.is_empty():
				segments.append(current)
				current = PackedVector2Array()
	
	if not current.is_empty():
		segments.append(current)
	
	return segments


func _ensure_counter_clockwise(points: PackedVector2Array) -> PackedVector2Array:
	var area: float = 0.0
	var count: int = points.size()
	for i: int in count:
		var a: Vector2 = points[i]
		var b: Vector2 = points[(i + 1) % count]
		area += (b.x - a.x) * (b.y + a.y)
	if area < 0.0:
		var reversed: PackedVector2Array = PackedVector2Array()
		for i: int in range(count - 1, -1, -1):
			reversed.append(points[i])
		return reversed
	return points


func _subdivide_for_line2d(points: PackedVector2Array, texture: Texture2D) -> PackedVector2Array:
	if not texture or points.size() < 2:
		return points
	
	var tex_width: float = float(texture.get_width())
	var result: PackedVector2Array = PackedVector2Array()
	
	for i: int in range(points.size() - 1):
		var a: Vector2 = points[i]
		var b: Vector2 = points[i + 1]
		var segment_length: float = a.distance_to(b)
		var steps: int = maxi(1, int(ceil(segment_length / tex_width)))
		
		result.append(a)
		for s: int in range(1, steps):
			result.append(a.lerp(b, float(s) / float(steps)))
	
	result.append(points[points.size() - 1])
	return result


func _get_closed_points(points: PackedVector2Array) -> PackedVector2Array:
	if points.is_empty():
		return points
	var closed: PackedVector2Array = points.duplicate()
	closed.append(points[0])
	return closed

 
func _setup_line2d(line: Line2D) -> void:
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.texture_mode = Line2D.LINE_TEXTURE_TILE
	line.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


func _draw() -> void:
	if not _polygon or _polygon.polygon.is_empty():
		return
	
	var points: PackedVector2Array = _polygon.polygon
	
	if not base_texture:
		draw_colored_polygon(points, Color(0.2, 0.5, 1.0, 0.25))
		draw_polyline(_get_closed_points(points), Color(0.4, 0.7, 1.0, 0.8), border_width, true)
	
	if _selection_state == LDObject.SelectionState.HIDDEN:
		return
	
	var outline_color: Color
	var fill_color: Color
	
	match _selection_state:
		LDObject.SelectionState.HOVERED:
			outline_color = Color(1.0, 1.0, 1.0, 0.6)
			fill_color = Color(1.0, 1.0, 1.0, 0.1)
		LDObject.SelectionState.SELECTED:
			var pulse: float = sin(Time.get_ticks_msec() * 0.005) * 0.5 + 0.5
			var alpha: float = lerpf(0.3, 1.0, pulse)
			outline_color = Color(1.0, 1.0, 1.0, alpha)
			fill_color = Color(1.0, 1.0, 1.0, alpha * 0.15)
	
	draw_colored_polygon(points, fill_color)
	draw_polyline(_get_closed_points(points), outline_color, 1.5, true)
	
	if _selection_state == LDObject.SelectionState.SELECTED:
		queue_redraw()


func _get_polygon_bounds() -> Rect2:
	if not _polygon or _polygon.polygon.is_empty():
		return Rect2()
	var bounds: Rect2 = Rect2(_polygon.polygon[0], Vector2.ZERO)
	for point: Vector2 in _polygon.polygon:
		bounds = bounds.expand(point)
	return bounds
