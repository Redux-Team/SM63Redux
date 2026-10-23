class_name LDTileFillTool
extends LDTool

@export var tile_tool: LDTileTool
@export var fill_color: Color = Color(0.49, 0.85, 0.34, 0.9)
@export var blocked_color: Color = Color(0.91, 0.35, 0.35, 0.6)

var _hover: Vector2i
var _region: Dictionary[Vector2i, bool] = {}
var _rings: Array[PackedVector2Array] = []
var _stale: bool = true


func _setup() -> void:
	editor.history_handler.changed.connect(_invalidate)
	editor.level_handler.layer_changed.connect(_invalidate.unbind(1))


func _activate() -> void:
	_invalidate()


func _deactivate() -> void:
	_region.clear()
	_rings.clear()


func _tool_input(event: InputEvent, _world_position: Vector2) -> bool:
	if editor.tool_handler.armed == null or editor.level_handler.active_layer == null:
		return false
	
	if event is InputEventMouseMotion:
		_track_cursor()
		return false
	
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if (
			mouse_button == null
			or mouse_button.button_index != MOUSE_BUTTON_LEFT
			or not mouse_button.pressed
	):
		return false
	
	_hover = _cell_at_cursor()
	_refresh()
	if _region.is_empty():
		SFX.play(SFX.LD_ERROR)
	else:
		tile_tool.apply(_region.duplicate(), false, "Fill Tiles")
	return true


func _view_changed() -> void:
	if editor.tool_handler.armed:
		_track_cursor()


func _draw_overlay(overlay: LDOverlay) -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	if layer == null or editor.tool_handler.armed == null:
		return
	
	var to_world: Transform2D = layer.get_objects_root().get_global_transform()
	var color: Color = fill_color if not _region.is_empty() else blocked_color
	for ring: PackedVector2Array in _rings:
		overlay.draw_world_polyline(to_world * TerrainPolygon.get_closed_points(ring), color, 2.0)


func _track_cursor() -> void:
	var cell: Vector2i = _cell_at_cursor()
	if cell != _hover or _stale:
		_hover = cell
		_refresh()


func _invalidate() -> void:
	_stale = true


func _refresh() -> void:
	_stale = false
	_region = TileGrid.region(tile_tool.get_layer_cells(), _hover)
	_rings.clear()
	var outline: Dictionary[Vector2i, bool] = _region.duplicate()
	if outline.is_empty():
		outline[_hover] = true
	for shape: TileGrid.Shape in TileGrid.trace(outline):
		_rings.append_array(shape.get_rings())


func _cell_at_cursor() -> Vector2i:
	return TileGrid.world_to_cell(
			editor.viewport_handler.get_layer_mouse(editor.level_handler.active_layer)
	)
