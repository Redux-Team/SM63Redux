extends LDTool

## Grid-based terrain painting. A stroke is a set of cells, applied as a set operation against the
## cells the terrain already covers, and the result is contour-traced straight back into polygon
## rings by [TileGrid] - so holes, splits and merges come out of the trace instead of being
## classified by hand the way the polygon add and cut tools have to. Nothing tile-shaped is stored:
## the cells are re-derived from the polygon every time the tool touches it, so a level saves and
## loads as plain polygons either way.
##
## Left-drag paints the selected terrain, right-drag erases whatever is under it. Painting a shape
## closed fills it in rather than leaving a hollow, so the only holes terrain ever carries are the
## ones somebody erased on purpose. Terrain of a different type is overwritten rather than merged,
## and terrain that is not cell-aligned is left alone entirely so a hand-drawn shape never gets
## quantised.


## A cell-aligned terrain polygon paired with the cells it covers.
class Patch:
	var poly: LDObjectPolygon
	var cells: Dictionary[Vector2i, bool]
	
	
	func _init(target: LDObjectPolygon, occupied: Dictionary[Vector2i, bool]) -> void:
		poly = target
		cells = occupied


## One group of polygons and the cells they should cover between them once a stroke lands, next to
## the cells they cover right now. Both the preview and the commit read the same plan, which is
## what keeps what a designer sees and what they get from ever drifting apart.
class Plan:
	var targets: Array[LDObjectPolygon]
	var cells: Dictionary[Vector2i, bool]
	var before: Dictionary[Vector2i, bool]
	
	
	func _init(group: Array[LDObjectPolygon], after: Dictionary[Vector2i, bool], current: Dictionary[Vector2i, bool]) -> void:
		targets = group
		cells = after
		before = current
	
	
	func is_noop() -> bool:
		if before.size() != cells.size():
			return false
		for cell: Vector2i in cells:
			if not before.has(cell):
				return false
		return true


const OUTLINE_ALPHA: float = 0.9
const OUTLINE_WIDTH: float = 2.0


## Where cell (0, 0) starts, in pixels. Half a cell by default, because the viewport's background
## grid draws its lines through the middle of its tile - line the tool up with the edges instead
## and every cell straddles four of the squares a designer is aiming at.
@export var cell_offset: Vector2 = Vector2(16.0, 16.0)


var _game_object: GameObject
var _cells: Dictionary[Vector2i, bool] = {}
var _hover: Vector2i
var _stroke_button: int = 0
var _is_painting: bool = false
var _is_erasing: bool = false
var _previews: Array[LDObjectPolygon] = []
var _hidden: Array[LDObjectPolygon] = []
var _brush_rings: Array[PackedVector2Array] = []


func get_tool_name() -> String:
	return "Tile"


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_CROSS


func wants_overlay() -> bool:
	return true


func can_place(obj: GameObject) -> bool:
	return obj != null and obj.get_placement_tool() == "polygon"


func _on_ready() -> void:
	TileGrid.cell_offset = cell_offset
	get_tool_handler().add_tool(self)
	LD.get_object_handler().selected_object_changed.connect(_on_object_changed)


func _on_enable() -> void:
	super()
	set_cursor_shape(Control.CURSOR_CROSS)
	_on_object_changed(LD.get_object_handler().get_selected_object())


func _on_disable() -> void:
	_reset_stroke()
	_clear_preview()
	super()


func _input(event: InputEvent) -> void:
	if not is_active():
		return
	var key: InputEventKey = event as InputEventKey
	if not key or not key.pressed or key.echo or key.keycode != KEY_ESCAPE:
		return
	if _is_painting:
		_reset_stroke()
		_refresh_preview()
	else:
		get_tool_handler().select_tool("select")
	get_viewport().set_input_as_handled()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or get_viewport().is_input_handled():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if event is InputEventMouseMotion:
		var cell: Vector2i = _cell_at_cursor()
		if cell == _hover:
			return
		if _is_painting and not viewport.is_panning():
			for step: Vector2i in TileGrid.line(_hover, cell):
				_cells.set(step, true)
		_hover = cell
		_refresh_preview()
		return
	
	var button: InputEventMouseButton = event as InputEventMouseButton
	if not button or not _is_stroke_button(button.button_index):
		return
	if button.pressed and not _is_painting and not viewport.is_panning():
		_begin_stroke(button.button_index)
	elif not button.pressed and _is_painting and button.button_index == _stroke_button:
		_commit_stroke()


## The preview polygons already carry the shape and its art, so the overlay only outlines the reach
## of the stroke - one line around the whole run of cells rather than a box each, which would tile
## over the very terrain the preview is there to show.
func draw_overlay(draw_node: CanvasItem) -> void:
	if not _game_object:
		return
	
	var xform: Transform2D = viewport.world_transform()
	var tint: Color = Color(LDPalette.danger() if _is_erasing else LDPalette.add_color(), OUTLINE_ALPHA)
	for ring: PackedVector2Array in _brush_rings:
		if ring.size() < 3:
			continue
		var screen: PackedVector2Array = _transformed(xform, ring)
		screen.append(screen.get(0))
		draw_node.draw_polyline(screen, tint, OUTLINE_WIDTH, true)


func _begin_stroke(button_index: int) -> void:
	_stroke_button = button_index
	_is_painting = true
	_is_erasing = button_index == MOUSE_BUTTON_RIGHT
	_hover = _cell_at_cursor()
	_cells.clear()
	_cells.set(_hover, true)
	_refresh_preview()


## Turns the stroke into one history action, running the same plan the preview was already showing.
func _commit_stroke() -> void:
	var brush: Dictionary[Vector2i, bool] = _cells.duplicate()
	var erasing: bool = _is_erasing
	_reset_stroke()
	_clear_preview()
	
	if brush.is_empty() or not _game_object:
		return
	
	var dos: Array[Callable] = []
	var undos: Array[Callable] = []
	for plan: Plan in _plan(brush, erasing):
		if not plan.is_noop():
			_rewrite(plan.targets, plan.cells, dos, undos)
	if dos.is_empty():
		return
	
	LD.get_history_handler().push("Erase Tiles" if erasing else "Paint Tiles",
		func() -> void:
			for step: Callable in dos:
				step.call(),
		func() -> void:
			for step: Callable in undos:
				step.call()
	)
	
	_refresh_preview()


func _reset_stroke() -> void:
	_cells.clear()
	_is_painting = false
	_is_erasing = false
	_stroke_button = 0


## The cells a stroke would land on: everything painted so far mid-drag, or just the cell under
## the cursor while idle, so hovering shows what a single click would do.
func _brush() -> Dictionary[Vector2i, bool]:
	if _is_painting:
		return _cells
	var single: Dictionary[Vector2i, bool] = {}
	single.set(_hover, true)
	return single


## Works out what a stroke would do without doing any of it. Matching terrain within reach is
## gathered into one group so it merges, terrain of any other type is trimmed where the stroke
## covers it, and an erase only ever trims.
func _plan(brush: Dictionary[Vector2i, bool], erasing: bool) -> Array[Plan]:
	var result: Array[Plan] = []
	var joined: Array[LDObjectPolygon] = []
	var joined_cells: Dictionary[Vector2i, bool] = brush.duplicate()
	var joined_before: Dictionary[Vector2i, bool] = {}
	var reach: Dictionary[Vector2i, bool] = TileGrid.dilate(brush)
	
	for patch: Patch in _survey(TileGrid.cell_bounds(reach)):
		if not erasing and patch.poly.source_object_id == _game_object.id:
			if not _overlaps(patch.cells, reach):
				continue
			joined.append(patch.poly)
			for cell: Vector2i in patch.cells:
				joined_cells.set(cell, true)
				joined_before.set(cell, true)
			continue
		if not _overlaps(patch.cells, brush):
			continue
		var single: Array[LDObjectPolygon] = [patch.poly]
		result.append(Plan.new(single, _without(patch.cells, brush), patch.cells))
	
	if not erasing:
		result.append(Plan.new(joined, TileGrid.close_gaps(joined_cells, joined_before), joined_before))
	
	return result


## Rebuilds the standing preview: the polygons a stroke would leave behind, shaped and styled the
## way they will really land, with the originals they replace hidden underneath. What sits on
## screen mid-drag is the result itself rather than an impression of it.
func _refresh_preview() -> void:
	_restore_hidden()
	_brush_rings.clear()
	
	if not _game_object or not is_active():
		_park_previews(0)
		_redraw()
		return
	
	## Traced once here rather than per redraw, so panning the camera over a long stroke only has
	## to re-transform the outline it already has.
	var brush: Dictionary[Vector2i, bool] = _brush()
	for shape: TileGrid.Shape in TileGrid.trace(brush):
		_brush_rings.append(shape.outer)
		_brush_rings.append_array(shape.holes)
	
	var used: int = 0
	for plan: Plan in _plan(brush, _is_erasing):
		if plan.is_noop():
			continue
		var template: LDObjectPolygon = plan.targets.get(0) if not plan.targets.is_empty() else null
		var source: GameObject = _game_object
		if template:
			source = GameDB.get_object(template.source_object_id)
		if not source:
			continue
		for target: LDObjectPolygon in plan.targets:
			target.modulate.a = 0.0
			_hidden.append(target)
		for shape: TileGrid.Shape in TileGrid.trace(plan.cells):
			var preview: LDObjectPolygon = _take_preview(used, source, template)
			if not preview:
				continue
			_shape_preview(preview, shape)
			used += 1
	
	_park_previews(used)
	_redraw()


## Preview instances stay parked rather than freed between refreshes, because respawning a large
## terrain polygon for every cell the cursor crosses would rebuild its decorations each time.
func _take_preview(index: int, source: GameObject, template: LDObjectPolygon) -> LDObjectPolygon:
	if index < _previews.size():
		var parked: LDObjectPolygon = _previews.get(index)
		if is_instance_valid(parked) and parked.source_object_id == source.id:
			parked.visible = true
			if template and parked.polygon_data != template.polygon_data:
				parked.polygon_data = template.polygon_data
			return parked
		if is_instance_valid(parked):
			parked.queue_free()
		_previews.remove_at(index)
	
	var instance: LDObject = source.get_editor_instance()
	var poly: LDObjectPolygon = instance as LDObjectPolygon
	if not poly:
		instance.queue_free()
		return null
	
	LD.get_area().add_object(poly)
	poly.init_properties(source)
	if template:
		poly.polygon_data = template.polygon_data
		poly.set_topline_overrides(template.get_topline_overrides())
	## Stays flagged as a preview so [method _survey] never mistakes it for real terrain, but drawn
	## at full strength so it reads as the finished shape.
	poly.is_preview = true
	poly.modulate = Color.WHITE
	_previews.insert(index, poly)
	return poly


func _shape_preview(preview: LDObjectPolygon, shape: TileGrid.Shape) -> void:
	preview.position = _shape_origin(shape)
	preview.apply_points_and_holes(_to_local(preview, shape.outer), _to_local_rings(preview, shape.holes))


func _park_previews(used: int) -> void:
	for i: int in range(used, _previews.size()):
		var poly: LDObjectPolygon = _previews.get(i)
		if is_instance_valid(poly):
			poly.visible = false


func _clear_preview() -> void:
	for poly: LDObjectPolygon in _previews:
		if is_instance_valid(poly):
			poly.queue_free()
	_previews.clear()
	_brush_rings.clear()
	_restore_hidden()


func _restore_hidden() -> void:
	for poly: LDObjectPolygon in _hidden:
		if is_instance_valid(poly):
			poly.modulate.a = 1.0
	_hidden.clear()


## The cell-aligned terrain polygons within reach of a stroke, with the cells they cover. Anything
## the grid cannot describe exactly is dropped here, which is what keeps hand-drawn terrain safe;
## anything outside the stroke's own cell range never gets rasterized at all.
func _survey(reach: Rect2i) -> Array[Patch]:
	var result: Array[Patch] = []
	
	for obj: LDObject in LD.get_area().get_all_objects_on_layer():
		var poly: LDObjectPolygon = obj as LDObjectPolygon
		if not poly or poly.is_preview or poly.get_outer_points().size() < 3:
			continue
		var outer: PackedVector2Array = _to_world(poly, poly.get_outer_points())
		if not TileGrid.point_bounds(outer).intersects(reach):
			continue
		if not TileGrid.is_aligned(outer):
			continue
		var holes: Array[PackedVector2Array] = []
		var aligned: bool = true
		for hole: PackedVector2Array in poly.get_holes():
			var world_hole: PackedVector2Array = _to_world(poly, hole)
			if not TileGrid.is_aligned(world_hole):
				aligned = false
				break
			holes.append(world_hole)
		if aligned:
			result.append(Patch.new(poly, TileGrid.rasterize(outer, holes)))
	
	return result


## Applies a cell set back onto the polygons that fed it. Extra regions spawn new objects and
## regions that vanished take their object with them, so a cut that splits terrain in two and an
## edit that joins two pieces back together both land in one action.
func _rewrite(targets: Array[LDObjectPolygon], cells: Dictionary[Vector2i, bool], dos: Array[Callable], undos: Array[Callable]) -> void:
	var shapes: Array[TileGrid.Shape] = TileGrid.trace(cells)
	var template: LDObjectPolygon = targets.get(0) if not targets.is_empty() else null
	var source: GameObject = _game_object
	if template:
		source = GameDB.get_object(template.source_object_id)
	
	for i: int in maxi(shapes.size(), targets.size()):
		if i >= shapes.size():
			_remove(targets.get(i), dos, undos)
		elif i < targets.size():
			_reshape(targets.get(i), shapes.get(i), dos, undos)
		else:
			_spawn(shapes.get(i), source, template, dos, undos)


func _reshape(poly: LDObjectPolygon, shape: TileGrid.Shape, dos: Array[Callable], undos: Array[Callable]) -> void:
	var old_outer: PackedVector2Array = poly.get_outer_points().duplicate()
	var old_holes: Array[PackedVector2Array] = poly.get_holes().duplicate()
	var new_outer: PackedVector2Array = _to_local(poly, shape.outer)
	var new_holes: Array[PackedVector2Array] = _to_local_rings(poly, shape.holes)
	
	dos.append(func() -> void:
		if is_instance_valid(poly):
			poly.apply_points_and_holes(new_outer, new_holes)
	)
	undos.append(func() -> void:
		if is_instance_valid(poly):
			poly.apply_points_and_holes(old_outer, old_holes)
	)


func _spawn(shape: TileGrid.Shape, source: GameObject, template: LDObjectPolygon, dos: Array[Callable], undos: Array[Callable]) -> void:
	if not source:
		return
	var instance: LDObject = source.get_editor_instance()
	var poly: LDObjectPolygon = instance as LDObjectPolygon
	if not poly:
		instance.queue_free()
		return
	
	LD.get_area().add_object(poly, Vector2i(_shape_origin(shape)))
	## Read back what add_object rounded to, so a fractional cell offset cannot leave the points
	## measured against a position the object never actually had.
	var origin: Vector2 = poly.position
	poly.init_properties(source)
	if template:
		poly.polygon_data = template.polygon_data
		poly.set_topline_overrides(template.get_topline_overrides())
	
	poly.apply_points_and_holes(_to_local(poly, shape.outer), _to_local_rings(poly, shape.holes))
	poly.place()
	## place() re-applies every property default, position included, so the object has to be put
	## back where its points were measured from.
	poly.set_property(&"position", origin)
	
	var parent: Node = poly.get_parent()
	LD.get_history_handler().track_detached([poly])
	dos.append(func() -> void:
		if is_instance_valid(poly) and not poly.is_inside_tree():
			parent.add_child(poly)
	)
	undos.append(func() -> void:
		if is_instance_valid(poly) and poly.is_inside_tree():
			_deselect(poly)
			poly.get_parent().remove_child(poly)
	)


## Drops a region that was erased away entirely. The object is handed to the history handler
## rather than freed, since an undo can still bring it back and nothing else owns it meanwhile.
func _remove(poly: LDObjectPolygon, dos: Array[Callable], undos: Array[Callable]) -> void:
	var parent: Node = poly.get_parent()
	var old_outer: PackedVector2Array = poly.get_outer_points().duplicate()
	var old_holes: Array[PackedVector2Array] = poly.get_holes().duplicate()
	
	LD.get_history_handler().track_detached([poly])
	dos.append(func() -> void:
		if is_instance_valid(poly) and poly.is_inside_tree():
			_deselect(poly)
			poly.get_parent().remove_child(poly)
	)
	undos.append(func() -> void:
		if is_instance_valid(poly) and not poly.is_inside_tree():
			parent.add_child(poly)
			poly.apply_points_and_holes(old_outer, old_holes)
	)


func _deselect(poly: LDObjectPolygon) -> void:
	if poly in viewport.get_selected_objects():
		viewport.clear_selection()


func _on_object_changed(obj: GameObject) -> void:
	_reset_stroke()
	_clear_preview()
	if not is_active():
		return
	if not obj or obj.get_placement_tool() != "polygon":
		_game_object = null
		get_tool_handler().select_tool("brush")
		return
	_game_object = obj
	_hover = _cell_at_cursor()
	_refresh_preview()


func _overlaps(cells: Dictionary[Vector2i, bool], other: Dictionary[Vector2i, bool]) -> bool:
	for cell: Vector2i in cells:
		if other.has(cell):
			return true
	return false


func _without(cells: Dictionary[Vector2i, bool], removed: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		if not removed.has(cell):
			result.set(cell, true)
	return result


func _shape_origin(shape: TileGrid.Shape) -> Vector2:
	var origin: Vector2 = shape.outer.get(0)
	for point: Vector2 in shape.outer:
		origin = origin.min(point)
	return origin


func _to_world(poly: LDObjectPolygon, points: PackedVector2Array) -> PackedVector2Array:
	return _transformed(poly.transform, points)


func _to_local(poly: LDObjectPolygon, points: PackedVector2Array) -> PackedVector2Array:
	return _transformed(poly.transform.affine_inverse(), points)


func _to_local_rings(poly: LDObjectPolygon, rings: Array[PackedVector2Array]) -> Array[PackedVector2Array]:
	var result: Array[PackedVector2Array] = []
	for ring: PackedVector2Array in rings:
		result.append(_to_local(poly, ring))
	return result


func _transformed(xform: Transform2D, points: PackedVector2Array) -> PackedVector2Array:
	var result: PackedVector2Array = PackedVector2Array()
	for point: Vector2 in points:
		result.append(xform * point)
	return result


func _cell_at_cursor() -> Vector2i:
	return TileGrid.world_to_cell(viewport.get_world_mouse())


func _is_stroke_button(button_index: int) -> bool:
	return button_index == MOUSE_BUTTON_LEFT or button_index == MOUSE_BUTTON_RIGHT


func _redraw() -> void:
	viewport.get_selection_overlay().queue_redraw()
