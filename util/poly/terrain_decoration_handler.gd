class_name DecorationHandler
extends Node2D


const DECORATION_EDGE_BUFFER: float = 32.0
const MAX_DECORATIONS: int = 350


var _canvas_items: Array[RID] = []
var _last_outer_points: PackedVector2Array = PackedVector2Array()
var _last_holes: Array[PackedVector2Array] = []
var _last_weightmap: Dictionary[Texture2D, float] = {}
var _last_density: float = -1.0
var _last_enabled: bool = false
var _last_rng_seed: int = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_EXIT_TREE:
		_clear()


func rebuild(outer_points: PackedVector2Array, holes: Array[PackedVector2Array], polygon_data: PolygonData, rng_seed: int, weightmap_override: Dictionary[Texture2D, float] = {}, density_override: float = -1.0, enabled: bool = true) -> void:
	var weightmap: Dictionary[Texture2D, float] = {}
	if not weightmap_override.is_empty():
		weightmap = weightmap_override
	elif polygon_data:
		weightmap = polygon_data.decoration_weightmap
	var density: float = density_override if density_override > 0.0 else (polygon_data.decoration_density if polygon_data else 20.0)
	var active: bool = enabled and not weightmap.is_empty()

	if _is_same_input(outer_points, holes, weightmap, density, active, rng_seed):
		return

	_last_outer_points = outer_points.duplicate()
	_last_holes = holes.duplicate()
	_last_weightmap = weightmap
	_last_density = density
	_last_enabled = active
	_last_rng_seed = rng_seed

	_clear()

	if Engine.is_editor_hint():
		return
	if not active or outer_points.size() < 3:
		return
	
	var eroded_outer: Array = Geometry2D.offset_polygon(outer_points, -DECORATION_EDGE_BUFFER)
	if eroded_outer.is_empty():
		return
	var inner_polygon: PackedVector2Array = eroded_outer.get(0)
	if inner_polygon.size() < 3:
		return
	
	var eroded_holes: Array[PackedVector2Array] = []
	for hole: PackedVector2Array in holes:
		var eroded_hole: Array = Geometry2D.offset_polygon(hole, DECORATION_EDGE_BUFFER)
		if not eroded_hole.is_empty() and (eroded_hole.get(0) as PackedVector2Array).size() >= 3:
			eroded_holes.append(eroded_hole.get(0))
	
	var bounds: Rect2 = Rect2(outer_points[0], Vector2.ZERO)
	for point: Vector2 in outer_points:
		bounds = bounds.expand(point)
	
	var area: float = bounds.size.x * bounds.size.y
	var candidate_count: int = int(area / 10000.0 * density)
	if candidate_count <= 0:
		return
	
	var cell_size: float = sqrt(area / float(candidate_count))
	var cols: int = maxi(1, int(ceil(bounds.size.x / cell_size)))
	var rows: int = maxi(1, int(ceil(bounds.size.y / cell_size)))
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var spatial_hash: SpatialHash = SpatialHash.new()
	var placements: Dictionary[Texture2D, Array] = {}
	var total_placed: int = 0
	
	for row: int in rows:
		if total_placed >= MAX_DECORATIONS:
			break
		for col: int in cols:
			if total_placed >= MAX_DECORATIONS:
				break
			rng.seed = rng_seed ^ (row * 2654435761) ^ (col * 2246822519)
			var cell_origin: Vector2 = bounds.position + Vector2(col * cell_size, row * cell_size)
			var point: Vector2 = cell_origin + Vector2(rng.randf() * cell_size, rng.randf() * cell_size)
			
			if not Geometry2D.is_point_in_polygon(point, inner_polygon):
				continue
			
			var in_hole: bool = false
			for eroded_hole: PackedVector2Array in eroded_holes:
				if Geometry2D.is_point_in_polygon(point, eroded_hole):
					in_hole = true
					break
			if in_hole:
				continue
			
			var tex_index: int = 0
			for tex: Texture2D in weightmap:
				if not tex:
					tex_index += 1
					continue
				rng.seed = rng_seed ^ (row * 2654435761) ^ (col * 2246822519) ^ (tex_index * 374761393)
				var chance: float = weightmap.get(tex)
				if rng.randf() * 100.0 > chance:
					tex_index += 1
					continue
				
				var half_size: Vector2 = Vector2(tex.get_size()) * 0.5
				if spatial_hash.overlaps(point, half_size):
					tex_index += 1
					continue
				
				spatial_hash.insert(point, half_size)
				
				if not placements.has(tex):
					placements[tex] = []
				placements.get(tex).append(point)
				total_placed += 1
				tex_index += 1
	
	var parent_item: RID = get_canvas_item()
	
	for tex: Texture2D in placements:
		var points: Array = placements.get(tex)
		if points.is_empty():
			continue
		
		var tex_size: Vector2 = Vector2(tex.get_size())
		var rid: RID = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, parent_item)
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST)
		
		for point: Variant in points:
			var p: Vector2 = point as Vector2
			var rect: Rect2 = Rect2(p - tex_size * 0.5, tex_size)
			RenderingServer.canvas_item_add_texture_rect(rid, rect, tex.get_rid())
		
		_canvas_items.append(rid)


func _clear() -> void:
	for rid: RID in _canvas_items:
		RenderingServer.free_rid(rid)
	_canvas_items.clear()


func _is_same_input(outer_points: PackedVector2Array, holes: Array[PackedVector2Array], weightmap: Dictionary[Texture2D, float], density: float, enabled: bool, rng_seed: int) -> bool:
	if enabled != _last_enabled:
		return false
	if rng_seed != _last_rng_seed:
		return false
	if density != _last_density:
		return false
	if weightmap != _last_weightmap:
		return false
	if outer_points != _last_outer_points:
		return false
	if holes.size() != _last_holes.size():
		return false
	for i: int in holes.size():
		if holes.get(i) != _last_holes.get(i):
			return false
	return true


class SpatialHash:
	var _cells: Dictionary[Vector2i, Array] = {}
	var _cell_size: float = 64.0
	
	
	func _cell_key(point: Vector2) -> Vector2i:
		return Vector2i(floori(point.x / _cell_size), floori(point.y / _cell_size))
	
	
	func _neighbor_keys(point: Vector2) -> Array[Vector2i]:
		var center: Vector2i = _cell_key(point)
		var keys: Array[Vector2i] = []
		for dy: int in 3:
			for dx: int in 3:
				keys.append(center + Vector2i(dx - 1, dy - 1))
		return keys
	
	
	func insert(point: Vector2, half_size: Vector2) -> void:
		var key: Vector2i = _cell_key(point)
		if not _cells.has(key):
			_cells[key] = []
		_cells.get(key).append({"point": point, "half_size": half_size})
	
	
	func overlaps(point: Vector2, half_size: Vector2) -> bool:
		for key: Vector2i in _neighbor_keys(point):
			if not _cells.has(key):
				continue
			for entry: Variant in _cells.get(key):
				var e: Dictionary = entry as Dictionary
				var other_point: Vector2 = e.get("point")
				var other_half: Vector2 = e.get("half_size")
				var combined: Vector2 = half_size + other_half
				if absf(point.x - other_point.x) < combined.x and absf(point.y - other_point.y) < combined.y:
					return true
		return false
