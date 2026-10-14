class_name LDTileTool
extends LDTool

const LAYER_REACH: int = 1 << 20

@export var preview_root: Node2D
@export var cell_offset: Vector2 = Vector2(16.0, 16.0)
@export var paint_color: Color = Color(0.49, 0.85, 0.34, 0.9)
@export var erase_color: Color = Color(0.91, 0.35, 0.35, 0.9)

var _cells: Dictionary[Vector2i, bool] = {}
var _hover: Vector2i
var _stroke_button: MouseButton = MOUSE_BUTTON_NONE
var _previews: Array[GameObject] = []
var _hidden: Array[GameObject] = []
var _brush_rings: Array[PackedVector2Array] = []


class Plan:
	var targets: Array[GameObject]
	var id: StringName
	var cells: Dictionary[Vector2i, bool]
	var before: Dictionary[Vector2i, bool]
	
	
	func _init(group: Array[GameObject], object_id: StringName, after: Dictionary[Vector2i, bool], current: Dictionary[Vector2i, bool]) -> void:
		targets = group
		id = object_id
		cells = after
		before = current
	
	
	func is_noop() -> bool:
		return cells.size() == before.size() and cells.keys().all(func(cell: Vector2i) -> bool: return before.has(cell))


func _setup() -> void:
	TileGrid.cell_offset = cell_offset
	editor.tool_handler.armed_changed.connect(_on_armed_changed.unbind(1))


func _activate() -> void:
	_hover = _cell_at_cursor()
	_refresh_preview()


func _deactivate() -> void:
	_reset_stroke()
	_clear_preview()


func _cancel() -> void:
	_reset_stroke()
	_refresh_preview()


func _tool_input(event: InputEvent, _world_position: Vector2) -> bool:
	if editor.tool_handler.armed == null:
		return false
	
	if event is InputEventMouseMotion:
		_track_cursor()
		return is_painting()
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or not mouse_button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return false
	
	if mouse_button.pressed and not is_painting():
		_stroke_button = mouse_button.button_index
		_hover = _cell_at_cursor()
		_cells = {_hover: true}
		_refresh_preview()
	elif not mouse_button.pressed and mouse_button.button_index == _stroke_button:
		_commit()
	return true


func _view_changed() -> void:
	preview_root.global_transform = editor.level_handler.active_layer.get_objects_root().get_global_transform()
	if editor.tool_handler.armed:
		_track_cursor()


func _track_cursor() -> void:
	var cell: Vector2i = _cell_at_cursor()
	if cell == _hover:
		return
	
	if is_painting():
		for step: Vector2i in TileGrid.line(_hover, cell):
			_cells.set(step, true)
	_hover = cell
	_refresh_preview()


func is_painting() -> bool:
	return _stroke_button != MOUSE_BUTTON_NONE


func is_erasing() -> bool:
	return _stroke_button == MOUSE_BUTTON_RIGHT


func _draw_overlay(overlay: LDOverlay) -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	if layer == null or editor.tool_handler.armed == null:
		return
	
	var to_world: Transform2D = layer.get_objects_root().get_global_transform()
	for ring: PackedVector2Array in _brush_rings:
		overlay.draw_world_polyline(to_world * TerrainPolygon.get_closed_points(ring), erase_color if is_erasing() else paint_color, 2.0)


func apply(brush: Dictionary[Vector2i, bool], erasing: bool, action_name: String) -> void:
	var plans: Array[Plan] = _plan(brush, erasing).filter(func(plan: Plan) -> bool: return not plan.is_noop())
	if plans.is_empty():
		return
	
	var history: LDHistoryHandler.Action = editor.history_handler.create(action_name)
	for plan: Plan in plans:
		_rewrite(plan, history)
	history.commit()


func get_layer_cells() -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	var everywhere: Rect2i = Rect2i(Vector2i.ONE * -LAYER_REACH, Vector2i.ONE * LAYER_REACH * 2)
	for object: GameObject in editor.level_handler.active_layer.get_objects():
		cells.merge(_rasterize(object, everywhere))
	
	return cells


func _commit() -> void:
	var brush: Dictionary[Vector2i, bool] = _cells.duplicate()
	var erasing: bool = is_erasing()
	_reset_stroke()
	_clear_preview()
	apply(brush, erasing, "Erase Tiles" if erasing else "Paint Tiles")
	_refresh_preview()


func _plan(brush: Dictionary[Vector2i, bool], erasing: bool) -> Array[Plan]:
	var result: Array[Plan] = []
	var paint_id: StringName = editor.tool_handler.armed.id
	var joined: Array[GameObject] = []
	var joined_cells: Dictionary[Vector2i, bool] = brush.duplicate()
	var joined_before: Dictionary[Vector2i, bool] = {}
	var reach: Dictionary[Vector2i, bool] = TileGrid.dilate(brush)
	var reach_bounds: Rect2i = TileGrid.cell_bounds(reach)
	for object: GameObject in editor.level_handler.active_layer.get_objects():
		var cells: Dictionary[Vector2i, bool] = _rasterize(object, reach_bounds)
		if cells.is_empty():
			continue
		
		if not erasing and object.id == paint_id and editor.tool_handler.matches_placement(object):
			if _overlaps(cells, reach):
				joined.append(object)
				joined_cells.merge(cells)
				joined_before.merge(cells)
		elif _overlaps(cells, brush):
			result.append(Plan.new([object], object.id, _without(cells, brush), cells))
	
	if not erasing:
		result.append(Plan.new(joined, paint_id, joined_cells, joined_before))
	
	return result


func _rasterize(object: GameObject, reach: Rect2i) -> Dictionary[Vector2i, bool]:
	var shape: PolygonShape = object.shape as PolygonShape
	if shape == null or shape.outer.size() < PolygonShape.MIN_POINTS:
		return {}
	
	var rings: Array = LDPolygonBooleanTool.to_layer_rings(object)
	if not TileGrid.point_bounds(rings.front()).intersects(reach) or not rings.all(func(ring: PackedVector2Array) -> bool: return TileGrid.is_aligned(ring)):
		return {}
	
	var holes: Array[PackedVector2Array] = []
	holes.assign(rings.slice(1))
	return TileGrid.rasterize(rings.front(), holes)


func _rewrite(plan: Plan, history: LDHistoryHandler.Action) -> void:
	var shapes: Array[TileGrid.Shape] = TileGrid.trace(plan.cells)
	for i: int in maxi(shapes.size(), plan.targets.size()):
		if i >= shapes.size():
			editor.object_handler.queue_removal(history, plan.targets.get(i))
		elif i < plan.targets.size():
			var target: GameObject = plan.targets.get(i)
			var polygon: PolygonShape = target.shape as PolygonShape
			var rings: Array[PackedVector2Array] = _localize(shapes.get(i), target.position)
			history.do(polygon.set.bind(&"tiled", true)).undo(polygon.set.bind(&"tiled", polygon.tiled))
			history.do(polygon.set_rings.bind(rings, [] as Array[Dictionary])).undo(polygon.set_rings.bind(polygon.get_rings(), polygon.get_toplines()))
		else:
			editor.object_handler.queue_addition(history, _spawn(plan, shapes.get(i)), editor.level_handler.active_layer)


func _spawn(plan: Plan, shape: TileGrid.Shape) -> GameObject:
	var origin: Vector2 = _origin(shape)
	var data: ObjectData = plan.targets.front().to_data() if not plan.targets.is_empty() else ObjectData.create(plan.id)
	if plan.targets.is_empty():
		editor.tool_handler.apply_placement_values(data)
	data.uuid = StringName(Packer.generate_uuid())
	data.position = origin
	data.shape = {}
	var object: GameObject = ObjectRegistry.spawn(data, GameObject.Context.EDITOR)
	(object.shape as PolygonShape).tiled = true
	(object.shape as PolygonShape).set_rings(_localize(shape, origin), [])
	return object


func _refresh_preview() -> void:
	_restore_hidden()
	_brush_rings.clear()
	var layer: LevelLayer = editor.level_handler.active_layer
	if not is_active() or layer == null or editor.tool_handler.armed == null or not shape_kinds.has(editor.tool_handler.armed.get_shape_kind()):
		_park_previews(0)
		return
	
	var brush: Dictionary[Vector2i, bool] = {_hover: true}
	if is_painting():
		brush = _cells
	for shape: TileGrid.Shape in TileGrid.trace(brush):
		_brush_rings.append_array(shape.get_rings())
	
	preview_root.global_transform = layer.get_objects_root().get_global_transform()
	var used: int = 0
	for plan: Plan in _plan(brush, is_erasing()):
		if plan.is_noop():
			continue
		
		for target: GameObject in plan.targets:
			target.visible = false
			_hidden.append(target)
		for shape: TileGrid.Shape in TileGrid.trace(plan.cells):
			var preview: GameObject = _take_preview(used, plan)
			var origin: Vector2 = _origin(shape)
			preview.position = origin
			(preview.shape as PolygonShape).set_rings(_localize(shape, origin), [])
			used += 1
	
	_park_previews(used)


func _take_preview(index: int, plan: Plan) -> GameObject:
	if index < _previews.size() and _previews.get(index).id == plan.id:
		var parked: GameObject = _previews.get(index)
		parked.visible = true
		return parked
	
	if index < _previews.size():
		_previews.get(index).free()
		_previews.remove_at(index)
	
	var data: ObjectData = plan.targets.front().to_data() if not plan.targets.is_empty() else ObjectData.create(plan.id)
	if plan.targets.is_empty():
		editor.tool_handler.apply_placement_values(data)
	data.shape = {}
	var preview: GameObject = ObjectRegistry.spawn(data, GameObject.Context.EDITOR)
	preview_root.add_child(preview)
	_previews.insert(index, preview)
	return preview


func _park_previews(used: int) -> void:
	for i: int in range(used, _previews.size()):
		_previews.get(i).visible = false


func _clear_preview() -> void:
	for preview: GameObject in _previews:
		preview.free()
	_previews.clear()
	_brush_rings.clear()
	_restore_hidden()


func _restore_hidden() -> void:
	for object: GameObject in _hidden:
		if is_instance_valid(object):
			object.visible = true
	_hidden.clear()


func _reset_stroke() -> void:
	_cells.clear()
	_stroke_button = MOUSE_BUTTON_NONE


func _cell_at_cursor() -> Vector2i:
	return TileGrid.world_to_cell(editor.viewport_handler.get_layer_mouse(editor.level_handler.active_layer))


func _on_armed_changed() -> void:
	if is_active():
		_reset_stroke()
		_clear_preview()
		_refresh_preview()


static func _origin(shape: TileGrid.Shape) -> Vector2:
	return TerrainPolygon.get_bounds(shape.outer).position


static func _localize(shape: TileGrid.Shape, origin: Vector2) -> Array[PackedVector2Array]:
	var rings: Array[PackedVector2Array] = []
	for ring: PackedVector2Array in shape.get_rings():
		rings.append(LDPolygonTool.localize(ring, origin))
	
	return rings


static func _overlaps(cells: Dictionary[Vector2i, bool], other: Dictionary[Vector2i, bool]) -> bool:
	return cells.keys().any(func(cell: Vector2i) -> bool: return other.has(cell))


static func _without(cells: Dictionary[Vector2i, bool], removed: Dictionary[Vector2i, bool]) -> Dictionary[Vector2i, bool]:
	var result: Dictionary[Vector2i, bool] = {}
	for cell: Vector2i in cells:
		if not removed.has(cell):
			result.set(cell, true)
	
	return result
