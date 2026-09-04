@tool
class_name PolygonSurface
extends Node2D

## The whole visual half of a polygon object: fill, outlines, toplines, topline shadows and
## scatter decorations. Both [LDObjectPolygon] and [LevelObjectTerrain] embed one of these, so
## what a level designer draws is built by the same code that builds it in game. Owners set the
## shape and the style overrides, then call [method rebuild].


signal rebuilt


const DEFAULT_TOPLINE_THRESHOLD: float = 0.55


@export var fill: Polygon2D
@export var shadow_container: Node2D
@export var decorations: DecorationHandler
@export var outline_container: Node2D
@export var topline_container: Node2D


var data: PolygonForm:
	set(d):
		if data and data.changed.is_connected(rebuild):
			data.changed.disconnect(rebuild)
		data = d
		if data and not data.changed.is_connected(rebuild):
			data.changed.connect(rebuild)
		rebuild()
var base_style_name: String = ""
var topline_style_name: String = ""
var decoration_style_name: String = ""
var collision_mode_name: String = ""
var decorations_enabled: bool = true
var rng_seed: int = 0

var _outer: PackedVector2Array = PackedVector2Array()
var _holes: Array[PackedVector2Array] = []
var _ring: PackedVector2Array = PackedVector2Array()
var _topline_overrides: Dictionary = {}


func _ready() -> void:
	rebuild()


func set_outer(points: PackedVector2Array) -> void:
	_outer = points
	rebuild()


func set_holes(holes: Array[PackedVector2Array]) -> void:
	_store_holes(holes)
	rebuild()


func set_shape(points: PackedVector2Array, holes: Array[PackedVector2Array]) -> void:
	_outer = points
	_store_holes(holes)
	rebuild()


func set_hole(index: int, points: PackedVector2Array) -> void:
	if index >= 0 and index < _holes.size():
		_holes[index] = points
		rebuild()


func add_hole(hole: PackedVector2Array) -> void:
	_holes.append(hole)
	rebuild()


func remove_hole(index: int) -> void:
	if index >= 0 and index < _holes.size():
		_holes.remove_at(index)
		rebuild()


func clear_holes() -> void:
	_holes.clear()
	rebuild()


func get_outer() -> PackedVector2Array:
	return _outer


func get_holes() -> Array[PackedVector2Array]:
	return _holes


func get_hole(index: int) -> PackedVector2Array:
	return _holes[index] if index >= 0 and index < _holes.size() else PackedVector2Array()


func get_hole_count() -> int:
	return _holes.size()


## The outer points and every hole stitched into one seam-bridged ring, as fed to the fill
## polygon and to solid collision.
func get_ring() -> PackedVector2Array:
	return _ring


func set_topline_overrides(overrides: Dictionary) -> void:
	_topline_overrides = overrides.duplicate()
	rebuild()


func get_topline_overrides() -> Dictionary:
	return _topline_overrides


func set_topline_override(key: String, on: bool) -> void:
	_topline_overrides[key] = on
	rebuild()


func clear_topline_override(key: String) -> void:
	_topline_overrides.erase(key)
	rebuild()


func get_base_style() -> PolygonBaseStyle:
	var preset: PolygonBaseStyle = PolygonStyleDB.get_base_style(base_style_name)
	return preset if preset else (data.base if data else null)


func get_topline_style() -> PolygonToplineStyle:
	var preset: PolygonToplineStyle = PolygonStyleDB.get_topline_style(topline_style_name)
	return preset if preset else (data.topline if data else null)


func get_decoration_style() -> PolygonDecorationStyle:
	var preset: PolygonDecorationStyle = PolygonStyleDB.get_decoration_style(decoration_style_name)
	return preset if preset else (data.decoration if data else null)


func get_collision_mode() -> PolygonForm.CollisionMode:
	var fallback: PolygonForm.CollisionMode = data.collision_mode if data else PolygonForm.CollisionMode.NONE
	return PolygonForm.parse_collision_mode(collision_mode_name, fallback)


func get_topline_threshold() -> float:
	var style: PolygonToplineStyle = get_topline_style()
	return style.angle_threshold if style else DEFAULT_TOPLINE_THRESHOLD


## The upward-facing runs of the outline, walked so that their normals always point out of the
## solid. Drives both the drawn topline and semisolid collision, so the two can never disagree.
func get_topline_segments() -> Array[PackedVector2Array]:
	if _outer.size() < 3:
		return []
	var threshold: float = get_topline_threshold()
	var segments: Array[PackedVector2Array] = TerrainPolygon.get_topline_segments(
		TerrainPolygon.ensure_clockwise(_outer), threshold, _topline_overrides
	)
	for hole: PackedVector2Array in _holes:
		segments.append_array(TerrainPolygon.get_topline_segments(
			TerrainPolygon.ensure_counter_clockwise(hole), threshold, _topline_overrides
		))
	return segments


## Every edge of the shape paired with whether it currently counts as a topline, for the
## level designer's per-edge toggles.
func get_topline_edges() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if _outer.size() < 3:
		return result
	var threshold: float = get_topline_threshold()
	_append_topline_edges(result, TerrainPolygon.ensure_clockwise(_outer), threshold)
	for hole: PackedVector2Array in _holes:
		_append_topline_edges(result, TerrainPolygon.ensure_counter_clockwise(hole), threshold)
	return result


func set_tint(tint: Color) -> void:
	for item: CanvasItem in [fill, outline_container, topline_container]:
		if item:
			item.modulate = tint


func rebuild() -> void:
	if not is_node_ready():
		return
	
	_ring = TerrainPolygon.build_ring(_outer, _holes)
	
	var base: PolygonBaseStyle = get_base_style()
	if fill:
		fill.polygon = _ring
		# An unbound surface (the template scene open in the Godot editor) keeps whatever the scene
		# authored. Clearing it to transparent there gets saved back into the scene, and a
		# transparent fill clips every child away - which is how the topline shadows went missing.
		if data:
			fill.texture = base.texture if base else null
			fill.color = base.color if base else Color.TRANSPARENT
	
	for container: Node2D in [shadow_container, outline_container, topline_container]:
		if container:
			for child: Node in container.get_children():
				container.remove_child(child)
				child.queue_free()
	
	if decorations:
		decorations.rebuild(_outer, _holes, get_decoration_style(), rng_seed, decorations_enabled)
	
	var line_mode: PolygonForm.LineMode = data.line_mode if data else PolygonForm.LineMode.NONE
	if _outer.size() >= 3 and line_mode != PolygonForm.LineMode.NONE:
		if line_mode == PolygonForm.LineMode.TOPLINE:
			_build_toplines()
		if base:
			_build_outlines(base.make_outline_style())
	
	rebuilt.emit()


func _build_toplines() -> void:
	var style: PolygonToplineStyle = get_topline_style()
	if not style:
		return
	
	var line_style: TerrainPolygon.LineStyle = style.make_line_style()
	var shadow_style: TerrainPolygon.LineStyle = style.make_shadow_style()
	var caps: TerrainPolygon.CapStyle = style.make_cap_style()
	
	for segment: PackedVector2Array in get_topline_segments():
		if topline_container:
			TerrainPolygon.add_topline_segment(topline_container, segment, line_style, caps)
		if shadow_container:
			TerrainPolygon.add_topline_shadow(shadow_container, segment, shadow_style, caps, style.shadow_gap)


func _build_outlines(style: TerrainPolygon.LineStyle) -> void:
	if not outline_container:
		return
	
	TerrainPolygon.add_outline(outline_container,
		TerrainPolygon.get_closed_points(TerrainPolygon.ensure_clockwise(_outer)), style)
	
	for hole: PackedVector2Array in _holes:
		TerrainPolygon.add_outline(outline_container,
			TerrainPolygon.get_closed_points(TerrainPolygon.ensure_counter_clockwise(hole)), style)


func _store_holes(holes: Array[PackedVector2Array]) -> void:
	_holes.clear()
	for hole: PackedVector2Array in holes:
		if hole.size() >= 3:
			_holes.append(hole)


func _append_topline_edges(result: Array[Dictionary], ring: PackedVector2Array, threshold: float) -> void:
	var count: int = ring.size()
	for i: int in count:
		var a: Vector2 = ring[i]
		var b: Vector2 = ring[(i + 1) % count]
		var key: String = TerrainPolygon.edge_midpoint_key(a, b)
		var on: bool = bool(_topline_overrides.get(key)) if _topline_overrides.has(key) else TerrainPolygon.is_top_edge(a, b, threshold)
		result.append({"a": a, "b": b, "mid": (a + b) * 0.5, "key": key, "on": on})
