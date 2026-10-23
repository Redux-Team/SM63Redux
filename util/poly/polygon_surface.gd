@tool
class_name PolygonSurface
extends Node2D

signal style_changed

enum LineMode {
	TOPLINE,
	EDGES_ONLY,
	NONE,
}

const DEFAULT_TOPLINE_THRESHOLD: float = 0.55

@export var line_mode: LineMode = LineMode.TOPLINE:
	set(value):
		line_mode = value
		_style_changed()
@export var base_style: PolygonBaseStyle:
	set(value):
		base_style = value
		_style_changed()
@export var topline_style: PolygonToplineStyle:
	set(value):
		topline_style = value
		_style_changed()
@export var decoration_style: PolygonDecorationStyle:
	set(value):
		decoration_style = value
		_style_changed()
@export_group("Nodes")
@export var fill: Polygon2D
@export var shadow_container: Node2D
@export var decorations: TerrainDecorations
@export var outline_container: Node2D
@export var topline_container: Node2D

var base_style_name: String = "":
	set(value):
		base_style_name = value
		_style_changed()
var topline_style_name: String = "":
	set(value):
		topline_style_name = value
		_style_changed()
var decoration_style_name: String = "":
	set(value):
		decoration_style_name = value
		_style_changed()
var fill_color: Color = Color.WHITE:
	set(value):
		fill_color = value
		queue_rebuild()
var decorations_enabled: bool = true:
	set(value):
		decorations_enabled = value
		queue_rebuild()
var rng_seed: int = 0:
	set(value):
		rng_seed = value
		queue_rebuild()

var _shape: PolygonShape
var _queued: bool = false


func _ready() -> void:
	queue_rebuild()


func draw_shape(shape: PolygonShape) -> void:
	_shape = shape
	if decorations and not is_inside_tree():
		decorations.prepare(
				shape.outer,
				shape.holes,
				get_decoration_style(),
				rng_seed,
				decorations_enabled,
		)
	queue_rebuild()


func get_base_style() -> PolygonBaseStyle:
	var preset: PolygonBaseStyle = PolygonStyleRegistry.find(
			PolygonStyleRegistry.Kind.BASE,
			base_style_name,
	) as PolygonBaseStyle
	return preset if preset else base_style


func get_topline_style() -> PolygonToplineStyle:
	var preset: PolygonToplineStyle = PolygonStyleRegistry.find(
			PolygonStyleRegistry.Kind.TOPLINE,
			topline_style_name,
	) as PolygonToplineStyle
	return preset if preset else topline_style


func get_decoration_style() -> PolygonDecorationStyle:
	var preset: PolygonDecorationStyle = PolygonStyleRegistry.find(
			PolygonStyleRegistry.Kind.DECORATION,
			decoration_style_name,
	) as PolygonDecorationStyle
	return preset if preset else decoration_style


func get_topline_threshold() -> float:
	var style: PolygonToplineStyle = get_topline_style()
	return style.angle_threshold if style else DEFAULT_TOPLINE_THRESHOLD


func queue_rebuild() -> void:
	if _queued or not is_inside_tree():
		return
	
	_queued = true
	rebuild.call_deferred()


func rebuild() -> void:
	_queued = false
	if not is_inside_tree() or _shape == null:
		return
	
	var base: PolygonBaseStyle = get_base_style()
	if fill:
		_apply_fill(_shape.get_pieces())
		fill.texture = base.texture if base else null
		fill.color = (base.color if base else Color.WHITE) * fill_color
	
	for container: Node2D in [shadow_container, outline_container, topline_container]:
		if container:
			for child: Node in container.get_children():
				child.queue_free()
	
	if decorations:
		decorations.rebuild(
				_shape.outer,
				_shape.holes,
				get_decoration_style(),
				rng_seed,
				decorations_enabled,
		)
	
	if _shape.outer.size() < 3 or line_mode == LineMode.NONE:
		return
	
	if line_mode == LineMode.TOPLINE:
		_build_toplines()
	if base:
		_build_outlines(base.make_outline_style())


func _apply_fill(pieces: Array[PackedVector2Array]) -> void:
	if pieces.size() <= 1:
		fill.polygons = []
		fill.polygon = pieces.front() if not pieces.is_empty() else PackedVector2Array()
		return
	
	var points: PackedVector2Array = PackedVector2Array()
	var indices: Array = []
	for piece: PackedVector2Array in pieces:
		indices.append(PackedInt32Array(range(points.size(), points.size() + piece.size())))
		points.append_array(piece)
	fill.polygon = points
	fill.polygons = indices


func _build_toplines() -> void:
	var style: PolygonToplineStyle = get_topline_style()
	if style == null:
		return
	
	var line: TerrainPolygon.LineStyle = style.make_line_style()
	var shadow: TerrainPolygon.LineStyle = style.make_shadow_style()
	var caps: TerrainPolygon.CapStyle = style.make_cap_style()
	for segment: PackedVector2Array in _shape.get_topline_segments():
		if topline_container:
			TerrainPolygon.add_topline_segment(topline_container, segment, line, caps)
		if shadow_container:
			TerrainPolygon.add_topline_shadow(
					shadow_container,
					segment,
					shadow,
					caps,
					style.shadow_gap,
			)


func _build_outlines(style: TerrainPolygon.LineStyle) -> void:
	if outline_container == null:
		return
	
	TerrainPolygon.add_outline(
			outline_container,
			TerrainPolygon.get_closed_points(TerrainPolygon.ensure_clockwise(_shape.outer)),
			style,
	)
	for hole: PackedVector2Array in _shape.holes:
		TerrainPolygon.add_outline(
				outline_container,
				TerrainPolygon.get_closed_points(TerrainPolygon.ensure_counter_clockwise(hole)),
				style,
		)


func _style_changed() -> void:
	queue_rebuild()
	style_changed.emit()
