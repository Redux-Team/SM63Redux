@abstract class_name TileGrid

const CELL_SIZE: int = 32
const ALIGN_EPSILON: float = 0.5
const PINCH_EPSILON: float = 0.1
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

static var cell_offset: Vector2 = Vector2(CELL_SIZE, CELL_SIZE) * 0.5


class Shape:
	var outer: PackedVector2Array
	var holes: Array[PackedVector2Array]
	
	
	func _init(outer_ring: PackedVector2Array, hole_rings: Array[PackedVector2Array]) -> void:
		outer = outer_ring
		holes = hole_rings
	
	
	func get_rings() -> Array[PackedVector2Array]:
		var rings: Array[PackedVector2Array] = [outer]
		rings.append_array(holes)
		return rings


class Ring:
	var points: PackedVector2Array
	var owners: Array[Vector2i]
	
	
	func _init(ring_points: PackedVector2Array, owner_cells: Array[Vector2i]) -> void:
		points = ring_points
		owners = owner_cells


static func world_to_cell(point: Vector2) -> Vector2i:
	var local: Vector2 = point - cell_offset
	return Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + cell_offset


static func is_aligned(points: PackedVector2Array) -> bool:
	for point: Vector2 in points:
		var local: Vector2 = point - cell_offset
		if absf(local.x - snappedf(local.x, CELL_SIZE)) > ALIGN_EPSILON or absf(local.y - snappedf(local.y, CELL_SIZE)) > ALIGN_EPSILON:
			return false
	
	return true


static func rasterize(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	if outer.size() < 3:
		return cells
	
	var half: Vector2 = Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	var area: Rect2i = point_bounds(outer)
	for y: int in range(area.position.y, area.end.y):
		for x: int in range(area.position.x, area.end.x):
			var cell: Vector2i = Vector2i(x, y)
			var centre: Vector2 = cell_to_world(cell) + half
			if Geometry2D.is_point_in_polygon(centre, outer) and not holes.any(func(hole: PackedVector2Array) -> bool: return Geometry2D.is_point_in_polygon(centre, hole)):
				cells.set(cell, true)
	
	return cells


static func trace(cells: Dictionary[Vector2i, bool]) -> Array[Shape]:
	var links: Dictionary[Vector2i, Array] = {}
	for cell: Vector2i in cells:
		if not cells.has(cell + Vector2i.UP):
			_link(links, cell, cell + Vector2i.RIGHT)
		if not cells.has(cell + Vector2i.RIGHT):
			_link(links, cell + Vector2i.RIGHT, cell + Vector2i.ONE)
		if not cells.has(cell + Vector2i.DOWN):
			_link(links, cell + Vector2i.ONE, cell + Vector2i.DOWN)
		if not cells.has(cell + Vector2i.LEFT):
			_link(links, cell + Vector2i.DOWN, cell)
	
	var outers: Array[Ring] = []
	var holes: Array[Ring] = []
	while not links.is_empty():
		var start: Vector2i = _first_corner(links)
		var corners: Array[Vector2i] = []
		var current: Vector2i = start
		var heading: Vector2i = Vector2i.ZERO
		while links.has(current):
			var outgoing: Array = links.get(current)
			var next: Vector2i = _pick_next(outgoing, current, heading)
			outgoing.erase(next)
			if outgoing.is_empty():
				links.erase(current)
			corners.append(current)
			heading = next - current
			current = next
			if current == start:
				break
		
		if corners.size() < 4:
			continue
		
		var ring: Ring = _to_ring(corners)
		if TerrainPolygon.signed_area(ring.points) < 0.0:
			outers.append(ring)
		else:
			holes.append(ring)
	
	var grouped: Array[Array] = []
	for outer: Ring in outers:
		grouped.append([outer])
	
	for hole: Ring in holes:
		var probe: Vector2 = _interior_probe(hole.points)
		var owner_index: int = -1
		var owner_area: float = 0.0
		for i: int in outers.size():
			var candidate: PackedVector2Array = outers.get(i).points
			var area: float = absf(TerrainPolygon.signed_area(candidate))
			if Geometry2D.is_point_in_polygon(probe, candidate) and (owner_index < 0 or area < owner_area):
				owner_index = i
				owner_area = area
		if owner_index >= 0:
			grouped.get(owner_index).append(hole)
	
	var shapes: Array[Shape] = []
	for entry: Array in grouped:
		var rings: Array[Ring] = []
		rings.assign(entry)
		_open_pinches(rings)
		var hole_points: Array[PackedVector2Array] = []
		for i: int in range(1, rings.size()):
			hole_points.append(rings.get(i).points)
		shapes.append(Shape.new(rings.front().points, hole_points))
	
	return shapes


static func dilate(cells: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		result.set(cell, true)
		for step: Vector2i in NEIGHBOURS:
			result.set(cell + step, true)
	
	return result


static func enclosed(cells: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	if cells.is_empty():
		return result
	
	var bounds: Rect2i = cell_bounds(cells).grow(1)
	var reached: Dictionary[Vector2i, bool] = {bounds.position: true}
	var frontier: Array[Vector2i] = [bounds.position]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in NEIGHBOURS:
			var next: Vector2i = cell + step
			if bounds.has_point(next) and not cells.has(next) and not reached.has(next):
				reached.set(next, true)
				frontier.append(next)
	
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if not cells.has(cell) and not reached.has(cell):
				result.set(cell, true)
	
	return result


static func region(cells: Dictionary[Vector2i, bool], start: Vector2i) -> Dictionary[Vector2i, bool]:
	var holes: Dictionary[Vector2i, bool] = enclosed(cells)
	var result: Dictionary[Vector2i, bool] = {}
	if not holes.has(start):
		return result
	
	result.set(start, true)
	var frontier: Array[Vector2i] = [start]
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in NEIGHBOURS:
			var next: Vector2i = cell + step
			if holes.has(next) and not result.has(next):
				result.set(next, true)
				frontier.append(next)
	
	return result


static func cell_bounds(cells: Dictionary[Vector2i, bool]) -> Rect2i:
	var keys: Array[Vector2i] = cells.keys()
	if keys.is_empty():
		return Rect2i()
	
	var bounds: Rect2i = Rect2i(keys.front(), Vector2i.ONE)
	for cell: Vector2i in keys:
		bounds = bounds.expand(cell).expand(cell + Vector2i.ONE)
	
	return bounds


static func point_bounds(points: PackedVector2Array) -> Rect2i:
	if points.is_empty():
		return Rect2i()
	
	var area: Rect2 = TerrainPolygon.get_bounds(points)
	var from: Vector2i = world_to_cell(area.position)
	var to: Vector2i = world_to_cell(area.end - Vector2(ALIGN_EPSILON, ALIGN_EPSILON))
	return Rect2i(from, to - from + Vector2i.ONE)


static func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var steps: int = maxi(absi(to.x - from.x), absi(to.y - from.y))
	if steps == 0:
		return [from]
	
	for i: int in steps + 1:
		result.append(Vector2i(Vector2(from).lerp(Vector2(to), float(i) / float(steps)).round()))
	
	return result


static func _link(links: Dictionary[Vector2i, Array], from: Vector2i, to: Vector2i) -> void:
	links.get_or_add(from, []).append(to)


static func _first_corner(links: Dictionary[Vector2i, Array]) -> Vector2i:
	var keys: Array[Vector2i] = links.keys()
	var best: Vector2i = keys.front()
	for corner: Vector2i in keys:
		if corner.y < best.y or (corner.y == best.y and corner.x < best.x):
			best = corner
	
	return best


static func _pick_next(outgoing: Array, current: Vector2i, heading: Vector2i) -> Vector2i:
	var best: Vector2i = outgoing.front()
	var best_turn: int = 2
	for candidate: Vector2i in outgoing:
		var direction: Vector2i = candidate - current
		var turn: int = heading.x * direction.y - heading.y * direction.x
		if turn < best_turn:
			best_turn = turn
			best = candidate
	
	return best


static func _to_ring(corners: Array[Vector2i]) -> Ring:
	var points: PackedVector2Array = PackedVector2Array()
	var owners: Array[Vector2i] = []
	var count: int = corners.size()
	for i: int in count:
		var current: Vector2i = corners.get(i)
		var into: Vector2i = current - corners.get((i - 1 + count) % count)
		var out_of: Vector2i = corners.get((i + 1) % count) - current
		if into.x * out_of.y - into.y * out_of.x == 0 and into.x * out_of.x + into.y * out_of.y > 0:
			continue
		
		points.append(cell_to_world(current))
		owners.append(_owner_cell(current, out_of))
	
	return Ring.new(points, owners)


static func _owner_cell(corner: Vector2i, out_of: Vector2i) -> Vector2i:
	match out_of:
		Vector2i.RIGHT:
			return corner
		Vector2i.DOWN:
			return corner + Vector2i.LEFT
		Vector2i.LEFT:
			return corner + Vector2i.LEFT + Vector2i.UP
	
	return corner + Vector2i.UP


static func _open_pinches(rings: Array[Ring]) -> void:
	var counts: Dictionary[Vector2, int] = {}
	for ring: Ring in rings:
		for point: Vector2 in ring.points:
			counts.set(point, counts.get(point, 0) + 1)
	
	var half: Vector2 = Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	for ring: Ring in rings:
		for i: int in ring.points.size():
			var point: Vector2 = ring.points.get(i)
			if counts.get(point, 0) >= 2:
				ring.points.set(i, point + (cell_to_world(ring.owners.get(i)) + half - point).normalized() * PINCH_EPSILON)


static func _interior_probe(ring: PackedVector2Array) -> Vector2:
	var corner: Vector2 = ring.get(0)
	for point: Vector2 in ring:
		if point.y < corner.y or (point.y == corner.y and point.x < corner.x):
			corner = point
	
	return corner + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
