@tool
class_name TerrainDecorations
extends Node2D

const HASH_X: int = 2_654_435_761
const HASH_Y: int = 2_246_822_519
const HASH_TEXTURE: int = 374_761_393

var _canvas_items: Array[RID] = []
var _signature: Array = []
var _placements: Dictionary[Texture2D, PackedVector2Array] = {}


func _notification(what: int) -> void:
	if what == NOTIFICATION_ENTER_TREE and _canvas_items.is_empty():
		_draw_placements(_placements)
	if what == NOTIFICATION_EXIT_TREE:
		_clear()


func rebuild(
		outer: PackedVector2Array,
		holes: Array[PackedVector2Array],
		style: PolygonDecorationStyle,
		rng_seed: int,
		enabled: bool,
) -> void:
	if not prepare(outer, holes, style, rng_seed, enabled) and not _canvas_items.is_empty():
		return
	
	_clear()
	if is_inside_tree():
		_draw_placements(_placements)


func prepare(
		outer: PackedVector2Array,
		holes: Array[PackedVector2Array],
		style: PolygonDecorationStyle,
		rng_seed: int,
		enabled: bool,
) -> bool:
	var active: bool = (
			enabled
			and style != null
			and not style.weightmap.is_empty()
			and style.max_count > 0
			and outer.size() >= 3
	)
	var signature: Array = [outer, holes.duplicate(), style, rng_seed, active]
	if signature == _signature:
		return false
	
	_signature = signature
	_placements.clear()
	if active and not Engine.is_editor_hint():
		_placements = _scatter(outer, holes, style, rng_seed)
	return true


func _scatter(
		outer: PackedVector2Array,
		holes: Array[PackedVector2Array],
		style: PolygonDecorationStyle,
		rng_seed: int,
) -> Dictionary[Texture2D, PackedVector2Array]:
	var placements: Dictionary[Texture2D, PackedVector2Array] = {}
	var eroded: Array[PackedVector2Array] = Geometry2D.offset_polygon(outer, -style.edge_buffer)
	if eroded.is_empty() or eroded.front().size() < 3:
		return placements
	
	var inner: PackedVector2Array = eroded.front()
	var eroded_holes: Array[PackedVector2Array] = []
	for hole: PackedVector2Array in holes:
		var grown: Array[PackedVector2Array] = Geometry2D.offset_polygon(hole, style.edge_buffer)
		if not grown.is_empty() and grown.front().size() >= 3:
			eroded_holes.append(grown.front())
	
	var bounds: Rect2 = TerrainPolygon.get_bounds(outer)
	var area: float = bounds.size.x * bounds.size.y
	var candidates: int = int(area / 10000.0 * style.density)
	if candidates <= 0:
		return placements
	
	var cell_size: float = sqrt(area / float(candidates))
	var columns: int = maxi(1, ceili(bounds.size.x / cell_size))
	var rows: int = maxi(1, ceili(bounds.size.y / cell_size))
	var textures: Array[Texture2D] = style.weightmap.keys()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	var spatial_hash: SpatialHash = SpatialHash.new()
	var placed: int = 0
	for row: int in rows:
		for column: int in columns:
			if placed >= style.max_count:
				break
			
			var cell_seed: int = rng_seed ^ (row * HASH_X) ^ (column * HASH_Y)
			if not _any_winner(rng, cell_seed, textures, style.weightmap):
				continue
			
			rng.seed = cell_seed
			var point: Vector2 = (
					bounds.position
					+ Vector2(column, row) * cell_size
					+ Vector2(rng.randf(), rng.randf()) * cell_size
			)
			if (
					not Geometry2D.is_point_in_polygon(point, inner)
					or eroded_holes.any(
							func(hole: PackedVector2Array) -> bool:
								return Geometry2D.is_point_in_polygon(point, hole)
			)):
				continue
			
			for index: int in textures.size():
				var texture: Texture2D = textures[index]
				if texture == null:
					continue
				
				rng.seed = cell_seed ^ (index * HASH_TEXTURE)
				if rng.randf() * 100.0 > style.weightmap[texture]:
					continue
				
				var half_size: Vector2 = Vector2(texture.get_size()) * 0.5
				if spatial_hash.overlaps(point, half_size):
					continue
				
				spatial_hash.insert(point, half_size)
				placements.get_or_add(texture, PackedVector2Array()).append(point)
				placed += 1
	
	return placements


func _any_winner(
		rng: RandomNumberGenerator,
		cell_seed: int,
		textures: Array[Texture2D],
		weightmap: Dictionary[Texture2D, float],
) -> bool:
	for index: int in textures.size():
		if textures[index] == null:
			continue
		
		rng.seed = cell_seed ^ (index * HASH_TEXTURE)
		if rng.randf() * 100.0 <= weightmap[textures[index]]:
			return true
	
	return false


func _draw_placements(placements: Dictionary[Texture2D, PackedVector2Array]) -> void:
	for texture: Texture2D in placements:
		var size: Vector2 = Vector2(texture.get_size())
		var item: RID = RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(item, get_canvas_item())
		RenderingServer.canvas_item_set_default_texture_filter(
				item,
				RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_NEAREST,
		)
		for point: Vector2 in placements[texture]:
			RenderingServer.canvas_item_add_texture_rect(
					item,
					Rect2(point - size * 0.5, size),
					texture.get_rid(),
			)
		_canvas_items.append(item)


func _clear() -> void:
	for item: RID in _canvas_items:
		RenderingServer.free_rid(item)
	_canvas_items.clear()


class SpatialHash:
	const CELL_SIZE: float = 64.0
	
	var _cells: Dictionary[Vector2i, Array] = {}
	
	
	func insert(point: Vector2, half_size: Vector2) -> void:
		_cells.get_or_add(_key(point), []).append(Rect2(point - half_size, half_size * 2.0))
	
	
	func overlaps(point: Vector2, half_size: Vector2) -> bool:
		var rect: Rect2 = Rect2(point - half_size, half_size * 2.0)
		var center: Vector2i = _key(point)
		for y: int in range(-1, 2):
			for x: int in range(-1, 2):
				for other: Rect2 in _cells.get(center + Vector2i(x, y), []):
					if rect.intersects(other):
						return true
		
		return false
	
	
	func _key(point: Vector2) -> Vector2i:
		return Vector2i(floori(point.x / CELL_SIZE), floori(point.y / CELL_SIZE))
