class_name LDTileShapeTool
extends LDTool

enum ShapeMode { LINE, RECTANGLE }

@export var tile_tool: LDTileTool
@export var mode: ShapeMode = ShapeMode.LINE
@export var paint_color: Color = Color(0.49, 0.85, 0.34, 0.9)
@export var erase_color: Color = Color(0.91, 0.35, 0.35, 0.9)

var _start: Vector2i
var _end: Vector2i
var _stroke_button: MouseButton = MOUSE_BUTTON_NONE
var _rings: Array[PackedVector2Array] = []


func _activate() -> void:
	_end = _cell_at_cursor()
	_refresh()


func _deactivate() -> void:
	_stroke_button = MOUSE_BUTTON_NONE
	_rings.clear()


func _cancel() -> void:
	_stroke_button = MOUSE_BUTTON_NONE
	_refresh()


func _tool_input(event: InputEvent, _world_position: Vector2) -> bool:
	if editor.tool_handler.armed == null or editor.level_handler.active_layer == null:
		return false
	
	if event is InputEventMouseMotion:
		_track_cursor()
		return _stroke_button != MOUSE_BUTTON_NONE
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or not mouse_button.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
		return false
	
	if mouse_button.pressed and _stroke_button == MOUSE_BUTTON_NONE:
		_stroke_button = mouse_button.button_index
		_start = _cell_at_cursor()
		_end = _start
		_refresh()
	elif not mouse_button.pressed and mouse_button.button_index == _stroke_button:
		var erasing: bool = _stroke_button == MOUSE_BUTTON_RIGHT
		var cells: Dictionary[Vector2i, bool] = get_cells()
		_stroke_button = MOUSE_BUTTON_NONE
		tile_tool.apply(cells, erasing, "%s %s" % ["Erase" if erasing else "Paint", "Tile Line" if mode == ShapeMode.LINE else "Tile Rectangle"])
		_refresh()
	return true


func _view_changed() -> void:
	if editor.tool_handler.armed:
		_track_cursor()


func _track_cursor() -> void:
	var cell: Vector2i = _cell_at_cursor()
	if cell != _end:
		_end = cell
		_refresh()


func get_cells() -> Dictionary[Vector2i, bool]:
	var cells: Dictionary[Vector2i, bool] = {}
	if _stroke_button == MOUSE_BUTTON_NONE:
		cells.set(_end, true)
		return cells
	
	if mode == ShapeMode.LINE:
		for cell: Vector2i in TileGrid.line(_start, _end):
			cells.set(cell, true)
		return cells
	
	var from: Vector2i = _start.min(_end)
	var to: Vector2i = _start.max(_end)
	for y: int in range(from.y, to.y + 1):
		for x: int in range(from.x, to.x + 1):
			cells.set(Vector2i(x, y), true)
	
	return cells


func _draw_overlay(overlay: LDOverlay) -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	if layer == null or editor.tool_handler.armed == null:
		return
	
	var to_world: Transform2D = layer.get_objects_root().get_global_transform()
	var color: Color = erase_color if _stroke_button == MOUSE_BUTTON_RIGHT else paint_color
	for ring: PackedVector2Array in _rings:
		overlay.draw_world_polyline(to_world * TerrainPolygon.get_closed_points(ring), color, 2.0)


func _refresh() -> void:
	_rings.clear()
	for shape: TileGrid.Shape in TileGrid.trace(get_cells()):
		_rings.append_array(shape.get_rings())


func _cell_at_cursor() -> Vector2i:
	return TileGrid.world_to_cell(editor.viewport_handler.get_layer_mouse(editor.level_handler.active_layer))
