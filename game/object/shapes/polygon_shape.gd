@tool
class_name PolygonShape
extends ObjectShape

signal changed

const MIN_POINTS: int = 3

@export var surface: PolygonSurface
@export var default_outer: PackedVector2Array = PackedVector2Array([Vector2(-32, -32), Vector2(32, -32), Vector2(32, 32), Vector2(-32, 32)])

var outer: PackedVector2Array = PackedVector2Array()
var holes: Array[PackedVector2Array] = []
var toplines: Array[Dictionary] = [{}]
var tiled: bool = false
var auto_toplines: bool = true:
	set(value):
		if auto_toplines != value:
			auto_toplines = value
			_changed()

var _pieces: Array[PackedVector2Array] = []
var _pieces_valid: bool = false


func _ready() -> void:
	if outer.is_empty():
		set_rings([default_outer], [{}])
	if is_instance_valid(surface) and not surface.style_changed.is_connected(_changed):
		surface.style_changed.connect(_changed)
	_changed()


func get_kind() -> Kind:
	return Kind.POLYGON


func from_data(data: Dictionary) -> void:
	var rings: Array[PackedVector2Array] = [data.get("outer", default_outer)]
	for hole: PackedVector2Array in data.get("holes", []):
		rings.append(hole)
	
	var overrides: Array[Dictionary] = []
	for i: int in rings.size():
		overrides.append({})
	for entry: Vector3i in data.get("toplines", []):
		if entry.x >= 0 and entry.x < overrides.size():
			overrides.get(entry.x).set(entry.y, entry.z != 0)
	
	tiled = data.get("tiled", false)
	set_rings(rings, overrides)


func to_data() -> Dictionary:
	var entries: Array[Vector3i] = []
	for ring: int in toplines.size():
		var overrides: Dictionary = toplines.get(ring)
		for edge: int in overrides:
			entries.append(Vector3i(ring, edge, 1 if overrides.get(edge) else 0))
	
	var data: Dictionary = {"outer": outer.duplicate(), "holes": holes.map(func(hole: PackedVector2Array) -> PackedVector2Array: return hole.duplicate()), "toplines": entries}
	if is_tiled():
		data.set("tiled", true)
	return data


func is_tiled() -> bool:
	var object: Node2D = get_parent() as Node2D
	if not tiled or object == null or not is_zero_approx(object.rotation) or not object.scale.is_equal_approx(Vector2.ONE):
		return false
	
	for ring: PackedVector2Array in get_rings():
		var placed: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in ring:
			placed.append(point + object.position)
		if not TileGrid.is_aligned(placed):
			return false
	
	return true


func get_local_bounds() -> Rect2:
	return TerrainPolygon.get_bounds(outer)


func contains_point(local_point: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(local_point, outer):
		return false
	
	return not holes.any(func(hole: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(local_point, hole))


func get_outlines() -> Array[PackedVector2Array]:
	return get_rings()


func get_rings() -> Array[PackedVector2Array]:
	var rings: Array[PackedVector2Array] = [outer.duplicate()]
	for hole: PackedVector2Array in holes:
		rings.append(hole.duplicate())
	return rings


func get_ring_points(ring: int) -> PackedVector2Array:
	return outer if ring == 0 else holes.get(ring - 1)


func get_toplines() -> Array[Dictionary]:
	var copies: Array[Dictionary] = []
	for overrides: Dictionary in toplines:
		copies.append(overrides.duplicate())
	
	return copies


func set_rings(rings: Array[PackedVector2Array], overrides: Array[Dictionary]) -> void:
	outer = (rings.front() as PackedVector2Array).duplicate() if not rings.is_empty() else PackedVector2Array()
	holes.clear()
	for hole: PackedVector2Array in rings.slice(1):
		if hole.size() >= MIN_POINTS:
			holes.append(hole.duplicate())
	toplines.clear()
	for ring: int in holes.size() + 1:
		toplines.append((overrides.get(ring) as Dictionary).duplicate() if ring < overrides.size() else {})
	_changed()


func get_pieces() -> Array[PackedVector2Array]:
	if not _pieces_valid:
		_pieces = TerrainPolygon.split_into_pieces(outer, holes)
		_pieces_valid = true
	
	return _pieces


func get_topline_threshold() -> float:
	return surface.get_topline_threshold() if is_instance_valid(surface) else PolygonSurface.DEFAULT_TOPLINE_THRESHOLD


func get_topline_flags(ring: int) -> Array[bool]:
	return TerrainPolygon.get_topline_flags(get_ring_points(ring), ring == 0, get_topline_threshold(), toplines.get(ring), auto_toplines)


func is_on_topline(global_point: Vector2, tolerance: float) -> bool:
	var point: Vector2 = get_global_transform().affine_inverse() * global_point
	for segment: PackedVector2Array in get_topline_segments():
		for i: int in segment.size() - 1:
			if Geometry2D.get_closest_point_to_segment(point, segment.get(i), segment.get(i + 1)).distance_to(point) <= tolerance:
				return true
	
	return false


func get_topline_segments() -> Array[PackedVector2Array]:
	var segments: Array[PackedVector2Array] = []
	if outer.size() < MIN_POINTS:
		return segments
	
	for ring: int in holes.size() + 1:
		segments.append_array(TerrainPolygon.get_topline_segments(get_ring_points(ring), get_topline_flags(ring), ring == 0))
	
	return segments


static func insert_override(overrides: Dictionary, index: int, count: int) -> Dictionary:
	var split: int = posmod(index - 1, count)
	var shifted: Dictionary = {}
	for edge: int in overrides:
		shifted.set(edge + 1 if edge >= index else edge, overrides.get(edge))
	if overrides.has(split):
		shifted.set(index, overrides.get(split))
		if index == 0:
			shifted.set(count, overrides.get(split))
	
	return shifted


static func remove_override(overrides: Dictionary, index: int, count: int) -> Dictionary:
	var merged_old: int = posmod(index - 1, count)
	var merged_new: int = index - 1 if index > 0 else count - 2
	var shifted: Dictionary = {}
	for edge: int in overrides:
		if edge == merged_old or edge == index:
			continue
		
		shifted.set(edge - 1 if edge > index else edge, overrides.get(edge))
	if overrides.has(merged_old):
		shifted.set(merged_new, overrides.get(merged_old))
	elif overrides.has(index):
		shifted.set(merged_new, overrides.get(index))
	
	return shifted


func _changed() -> void:
	_pieces_valid = false
	if is_instance_valid(surface):
		surface.draw_shape(self)
	var object: GameObject = get_parent() as GameObject
	if object:
		object.invalidate_bounds()
	changed.emit()
