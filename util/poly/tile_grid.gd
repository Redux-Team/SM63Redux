@abstract class_name TileGrid

## Grid geometry for the level designer's tile tool. Terrain is edited as a set of grid cells and
## contour-traced straight back into the outer ring and holes an [LDObjectPolygon] already speaks,
## so the tile view is never stored anywhere - it is re-derived from the polygon on every edit.
## Boundaries are walked so that cells meeting at only a corner stay one region, which keeps a
## diagonal run of tiles a single polygon instead of one per tile.


const CELL_SIZE: int = 32
const ALIGN_EPSILON: float = 0.5
## How far a corner shared by two parts of the same shape is eased apart. Far enough that the
## polygon reads as strictly simple, far short of [constant ALIGN_EPSILON] so the point still
## counts as sitting on the grid.
const PINCH_EPSILON: float = 0.1
## Empty space is walked four-way while the solid is traced eight-way, which is the pairing that
## keeps two cells touching at a corner one region without trapping the gap beside them.
const NEIGHBOURS: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]


## Where cell (0, 0) starts, in pixels. The viewport's background grid draws its lines through the
## middle of its tile rather than along the edges, so an unshifted grid puts every cell centred on
## an intersection instead of inside a square. Owned by the tile tool's exported offset.
static var cell_offset: Vector2 = Vector2(CELL_SIZE, CELL_SIZE) * 0.5


## One traced region: a clockwise outer ring plus the counter-clockwise rings it encloses, in the
## winding [PolygonSurface] expects.
class Shape:
	var outer: PackedVector2Array
	var holes: Array[PackedVector2Array]
	
	
	func _init(outer_ring: PackedVector2Array, hole_rings: Array[PackedVector2Array]) -> void:
		outer = outer_ring
		holes = hole_rings


## A traced ring plus, per point, the filled cell the walk was inside when it turned there. Only
## [method _open_pinches] needs those cells, so they never leave this file.
class Ring:
	var points: PackedVector2Array
	var owners: Array[Vector2i]
	
	
	func _init(ring_points: PackedVector2Array, owner_cells: Array[Vector2i]) -> void:
		points = ring_points
		owners = owner_cells


static func world_to_cell(pos: Vector2) -> Vector2i:
	var local: Vector2 = pos - cell_offset
	return Vector2i(floori(local.x / CELL_SIZE), floori(local.y / CELL_SIZE))


static func cell_to_world(cell: Vector2i) -> Vector2:
	return Vector2(cell) * CELL_SIZE + cell_offset


static func cell_rect(cell: Vector2i) -> Rect2:
	return Rect2(cell_to_world(cell), Vector2(CELL_SIZE, CELL_SIZE))


## Whether every point sits on a cell corner. Terrain that fails this was not built on the grid,
## and the tile tool leaves it alone rather than quantising someone's hand-drawn shape.
static func is_aligned(points: PackedVector2Array) -> bool:
	for point: Vector2 in points:
		var local: Vector2 = point - cell_offset
		if absf(local.x - snappedf(local.x, CELL_SIZE)) > ALIGN_EPSILON:
			return false
		if absf(local.y - snappedf(local.y, CELL_SIZE)) > ALIGN_EPSILON:
			return false
	return true


## The cells a polygon-with-holes covers, by cell centre. Centres never land on a cell-aligned
## edge, so the containment tests can never come out ambiguous.
static func rasterize(outer: PackedVector2Array, holes: Array[PackedVector2Array]) -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	if outer.size() < 3:
		return cells
	
	var bounds: Rect2 = Rect2(outer.get(0), Vector2.ZERO)
	for point: Vector2 in outer:
		bounds = bounds.expand(point)
	
	var half: Vector2 = Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	var from: Vector2i = world_to_cell(bounds.position)
	var to: Vector2i = world_to_cell(bounds.end - Vector2(ALIGN_EPSILON, ALIGN_EPSILON))
	
	for y: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			var cell: Vector2i = Vector2i(x, y)
			var centre: Vector2 = cell_to_world(cell) + half
			if not Geometry2D.is_point_in_polygon(centre, outer):
				continue
			var in_hole: bool = false
			for hole: PackedVector2Array in holes:
				if Geometry2D.is_point_in_polygon(centre, hole):
					in_hole = true
					break
			if not in_hole:
				cells.set(cell, true)
	
	return cells


## Walks the boundary of a cell set into rings and pairs each hole with the region enclosing it.
## Splits, merges and holes all fall out of the walk, so no case ever has to be classified.
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
		var group: Array[Ring] = [outer]
		grouped.append(group)
	
	for hole: Ring in holes:
		var probe: Vector2 = _interior_probe(hole.points)
		var owner_index: int = -1
		var owner_area: float = 0.0
		for i: int in outers.size():
			var candidate: PackedVector2Array = outers.get(i).points
			if not Geometry2D.is_point_in_polygon(probe, candidate):
				continue
			var area: float = absf(TerrainPolygon.signed_area(candidate))
			if owner_index < 0 or area < owner_area:
				owner_index = i
				owner_area = area
		if owner_index >= 0:
			(grouped.get(owner_index) as Array[Ring]).append(hole)
	
	var shapes: Array[Shape] = []
	for entry: Array in grouped:
		var rings: Array[Ring] = entry
		_open_pinches(rings)
		var hole_points: Array[PackedVector2Array] = []
		for i: int in range(1, rings.size()):
			hole_points.append(rings.get(i).points)
		shapes.append(Shape.new(rings.get(0).points, hole_points))
	
	return shapes


## Two cells meeting only at a corner leave the shape touching itself there, and a self-touching
## polygon is one Godot's convex decomposition refuses - which is what breaks a staircase, or a
## hole that grazes the outline. Easing each visit of a shared corner towards the cell it was
## walked out of pulls the two apart, by far less than the grid tolerance so nothing counts as
## having left the grid.
static func _open_pinches(rings: Array[Ring]) -> void:
	var counts: Dictionary[Vector2, int] = {}
	for ring: Ring in rings:
		for point: Vector2 in ring.points:
			counts.set(point, counts.get(point, 0) + 1)
	
	var half: Vector2 = Vector2(CELL_SIZE, CELL_SIZE) * 0.5
	for ring: Ring in rings:
		for i: int in ring.points.size():
			var point: Vector2 = ring.points.get(i)
			if counts.get(point, 0) < 2:
				continue
			var centre: Vector2 = cell_to_world(ring.owners.get(i)) + half
			ring.points.set(i, point + (centre - point).normalized() * PINCH_EPSILON)


## The cells a stroke would join onto, so painting beside existing terrain merges with it rather
## than dropping a second polygon flush against the first.
static func dilate(cells: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		result.set(cell, true)
		for step: Vector2i in NEIGHBOURS:
			result.set(cell + step, true)
	return result


## The empty cells a set seals off from the outside - the gaps that would come back out of
## [method trace] as holes.
static func enclosed(cells: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	if cells.is_empty():
		return result
	
	## One clear cell of margin all round, so the walk can always get behind the shape.
	var bounds: Rect2i = cell_bounds(cells).grow(1)
	var reached: Dictionary[Vector2i, bool] = {}
	var frontier: Array[Vector2i] = [bounds.position]
	reached.set(bounds.position, true)
	
	while not frontier.is_empty():
		var cell: Vector2i = frontier.pop_back()
		for step: Vector2i in NEIGHBOURS:
			var next: Vector2i = cell + step
			if not bounds.has_point(next) or cells.has(next) or reached.has(next):
				continue
			reached.set(next, true)
			frontier.append(next)
	
	for y: int in range(bounds.position.y, bounds.end.y):
		for x: int in range(bounds.position.x, bounds.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if not cells.has(cell) and not reached.has(cell):
				result.set(cell, true)
	
	return result


## Solidifies whatever a stroke sealed shut. A gap the outside could still reach beforehand and
## cannot afterwards was closed over by the stroke itself, so it fills in; a gap that was already
## sealed is a hole somebody cut on purpose and survives untouched.
static func close_gaps(after: Dictionary[Vector2i, bool], before: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var sealed: Dictionary[Vector2i, bool] = enclosed(after)
	if sealed.is_empty():
		return after
	
	var already_sealed: Dictionary[Vector2i, bool] = enclosed(before)
	var result: Dictionary[Vector2i, bool] = after.duplicate()
	for cell: Vector2i in sealed:
		if not already_sealed.has(cell):
			result.set(cell, true)
	return result


## The inclusive cell range a set of cells spans, for cheap overlap rejects.
static func cell_bounds(cells: Dictionary[Vector2i, bool]) -> Rect2i:
	var from: Vector2i = Vector2i.ZERO
	var to: Vector2i = Vector2i.ZERO
	var found: bool = false
	for cell: Vector2i in cells:
		if not found:
			from = cell
			to = cell
			found = true
			continue
		from = Vector2i(mini(from.x, cell.x), mini(from.y, cell.y))
		to = Vector2i(maxi(to.x, cell.x), maxi(to.y, cell.y))
	return Rect2i(from, to - from + Vector2i.ONE) if found else Rect2i()


## The same range for a polygon, without paying to rasterize it first.
static func point_bounds(points: PackedVector2Array) -> Rect2i:
	if points.is_empty():
		return Rect2i()
	var area: Rect2 = Rect2(points.get(0), Vector2.ZERO)
	for point: Vector2 in points:
		area = area.expand(point)
	var from: Vector2i = world_to_cell(area.position)
	var to: Vector2i = world_to_cell(area.end - Vector2(ALIGN_EPSILON, ALIGN_EPSILON))
	return Rect2i(from, to - from + Vector2i.ONE)


## Fills the gap a fast drag leaves between two sampled cells.
static func line(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var delta: Vector2i = to - from
	var steps: int = maxi(absi(delta.x), absi(delta.y))
	if steps == 0:
		result.append(from)
		return result
	for i: int in range(steps + 1):
		result.append(Vector2i(Vector2(from).lerp(Vector2(to), float(i) / float(steps)).round()))
	return result


static func _link(links: Dictionary[Vector2i, Array], from: Vector2i, to: Vector2i) -> void:
	if not links.has(from):
		links.set(from, [])
	(links.get(from) as Array).append(to)


## The lexicographically smallest corner, which is always a convex corner of an outer boundary and
## so has exactly one way out - starting anywhere else could split a region at a diagonal pinch.
static func _first_corner(links: Dictionary[Vector2i, Array]) -> Vector2i:
	var best: Vector2i = Vector2i.ZERO
	var found: bool = false
	for corner: Vector2i in links:
		if not found or corner.y < best.y or (corner.y == best.y and corner.x < best.x):
			best = corner
			found = true
	return best


## Four edges meet where two cells touch only at a corner. Always taking the sharpest turn back
## into the solid keeps those two cells in one ring instead of tracing them as separate regions.
static func _pick_next(outgoing: Array, current: Vector2i, heading: Vector2i) -> Vector2i:
	var best: Vector2i = outgoing.get(0)
	var best_turn: int = 2
	for candidate: Vector2i in outgoing:
		var direction: Vector2i = candidate - current
		var turn: int = heading.x * direction.y - heading.y * direction.x
		if turn < best_turn:
			best_turn = turn
			best = candidate
	return best


## Corner steps to world points, dropping every corner that only continues a straight run so a
## painted block comes out with four points rather than one per cell.
static func _to_ring(corners: Array[Vector2i]) -> Ring:
	var points: PackedVector2Array = PackedVector2Array()
	var owners: Array[Vector2i] = []
	var count: int = corners.size()
	for i: int in count:
		var previous: Vector2i = corners.get((i - 1 + count) % count)
		var current: Vector2i = corners.get(i)
		var next: Vector2i = corners.get((i + 1) % count)
		var into: Vector2i = current - previous
		var out_of: Vector2i = next - current
		if into.x * out_of.y - into.y * out_of.x == 0 and into.x * out_of.x + into.y * out_of.y > 0:
			continue
		points.append(cell_to_world(current))
		owners.append(_owner_cell(current, out_of))
	return Ring.new(points, owners)


## Which of the four cells around a corner the walk was inside when it turned there. Edges are
## emitted with the solid on the right, so the direction the walk leaves by names the cell.
static func _owner_cell(corner: Vector2i, out_of: Vector2i) -> Vector2i:
	if out_of == Vector2i.RIGHT:
		return corner
	if out_of == Vector2i.DOWN:
		return corner + Vector2i.LEFT
	if out_of == Vector2i.LEFT:
		return corner + Vector2i.LEFT + Vector2i.UP
	return corner + Vector2i.UP


## A point safely inside a hole: its topmost-leftmost corner is the top-left of a cell the hole
## covers, so that cell's centre is always interior.
static func _interior_probe(ring: PackedVector2Array) -> Vector2:
	var corner: Vector2 = ring.get(0)
	for point: Vector2 in ring:
		if point.y < corner.y or (point.y == corner.y and point.x < corner.x):
			corner = point
	return corner + Vector2(CELL_SIZE, CELL_SIZE) * 0.5
