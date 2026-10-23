class_name LDOverlay
extends LDComponent

const PULSE_SPEED: float = 2.5
const PULSE_MIN: float = 0.3
const POLYGON_OUTLINE_WIDTH: float = 1.5
const SEMISOLID_HINT: Color = Color(1.0, 0.82, 0.25, 0.9)
const SEMISOLID_HINT_WIDTH: float = 3.0

@export var canvas: Control
@export var selection_color: Color = Color("6496ed")
@export var highlight: LDHighlight
@export var polygon_selected_outline: Color = Color.WHITE
@export var polygon_selected_fill: Color = Color(1.0, 1.0, 1.0, 0.15)
@export var hover_tint: Color = Color.WHITE
@export var hover_tint_min: float = 0.06
@export var hover_tint_max: float = 0.22
@export var hover_pulse_speed: float = 0.6


func _process(_delta: float) -> void:
	canvas.queue_redraw()


func _setup() -> void:
	canvas.draw.connect(_on_draw)


func draw_object_outline(object: GameObject, color: Color, width: float = 1.0) -> void:
	var to_screen: Transform2D = editor.world.get_canvas_transform() * object.get_global_transform()
	for outline: PackedVector2Array in object.get_outlines():
		if outline.size() >= 2:
			canvas.draw_polyline(
					to_screen * TerrainPolygon.get_closed_points(outline),
					color,
					width,
			)


func draw_world_rect(world_rect: Rect2, color: Color, filled: bool = false) -> void:
	var to_screen: Transform2D = editor.world.get_canvas_transform()
	var rect: Rect2 = \
			Rect2(to_screen * world_rect.position, world_rect.size * to_screen.get_scale())
	canvas.draw_rect(rect, color, filled)


func draw_world_line(from: Vector2, to: Vector2, color: Color, width: float = 1.0) -> void:
	var to_screen: Transform2D = editor.world.get_canvas_transform()
	canvas.draw_line(to_screen * from, to_screen * to, color, width)


func draw_world_polygon(points: PackedVector2Array, color: Color) -> void:
	if points.size() >= 3 and not Geometry2D.triangulate_polygon(points).is_empty():
		canvas.draw_colored_polygon(editor.world.get_canvas_transform() * points, color)


func draw_world_polyline(points: PackedVector2Array, color: Color, width: float = 1.0) -> void:
	if points.size() >= 2:
		canvas.draw_polyline(editor.world.get_canvas_transform() * points, color, width)


func draw_world_circle(center: Vector2, radius: float, color: Color) -> void:
	canvas.draw_circle(editor.world.get_canvas_transform() * center, radius, color, false)


func _on_draw() -> void:
	if editor.level_handler.active_area == null:
		return
	
	var hovered: GameObject = highlight.hovered
	if is_instance_valid(hovered) and not editor.object_handler.selection.has(hovered):
		_draw_highlight(hovered, false)
	
	for object: GameObject in editor.object_handler.selection.get_objects():
		_draw_highlight(object, true)
	
	editor.tool_handler.active_tool._draw_overlay(self)


func _draw_highlight(object: GameObject, selected: bool) -> void:
	if not selected:
		if object.shape is PolygonShape or not LDHighlight.has_texture_visuals(object):
			_draw_hover_tint(object)
	elif object.shape is PolygonShape:
		_draw_polygon_highlight(object)
	elif not LDHighlight.has_texture_visuals(object):
		draw_object_outline(object, selection_color)


func _draw_hover_tint(object: GameObject) -> void:
	var wave: float = sin(Time.get_ticks_msec() / 1000.0 * hover_pulse_speed * TAU) * 0.5 + 0.5
	var tint: Color = Color(hover_tint, lerpf(hover_tint_min, hover_tint_max, wave))
	var to_screen: Transform2D = editor.world.get_canvas_transform() * object.get_global_transform()
	for outline: PackedVector2Array in object.get_outlines():
		var points: PackedVector2Array = to_screen * outline
		if (
				points.size() >= PolygonShape.MIN_POINTS
				and not Geometry2D.triangulate_polygon(points).is_empty()
		):
			canvas.draw_colored_polygon(points, tint)


func _draw_polygon_highlight(object: GameObject) -> void:
	var shape: PolygonShape = object.shape as PolygonShape
	var to_screen: Transform2D = editor.world.get_canvas_transform() * object.get_global_transform()
	var pulse: float = \
			lerpf(PULSE_MIN, 1.0, sin(Time.get_ticks_msec() / 1000.0 * PULSE_SPEED) * 0.5 + 0.5)
	var outline: Color = Color(polygon_selected_outline, polygon_selected_outline.a * pulse)
	var fill: Color = Color(polygon_selected_fill, polygon_selected_fill.a * pulse)
	var outer: PackedVector2Array = to_screen * shape.outer
	if (
			outer.size() >= PolygonShape.MIN_POINTS
			and not Geometry2D.triangulate_polygon(outer).is_empty()
	):
		canvas.draw_colored_polygon(outer, fill)
	for ring: PackedVector2Array in shape.get_rings():
		canvas.draw_polyline(
				to_screen * TerrainPolygon.get_closed_points(ring),
				outline,
				POLYGON_OUTLINE_WIDTH,
				true,
		)
	
	if object.get_value(&"collision_mode") != PolygonCollision.CollisionMode.SEMISOLID:
		return
	
	for segment: PackedVector2Array in shape.get_topline_segments():
		if segment.size() >= 2:
			canvas.draw_polyline(to_screen * segment, SEMISOLID_HINT, SEMISOLID_HINT_WIDTH, true)
