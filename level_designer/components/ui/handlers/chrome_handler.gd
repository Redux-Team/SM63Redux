class_name LDUIChromeHandler
extends Node


const ACTIVE_CLASS: StringName = &"Active"
const PLACEMENT_ICONS: Dictionary[String, Texture2D] = {
	"brush": preload("res://assets/textures/level_designer/ui_icons/brush.svg"),
	"block": preload("res://assets/textures/level_designer/ui_icons/block.svg"),
	"polygon": preload("res://assets/textures/level_designer/ui_icons/polygon.svg"),
	"path": preload("res://assets/textures/level_designer/ui_icons/path.svg"),
	"telescoping": preload("res://assets/textures/level_designer/ui_icons/telescoping.svg"),
}
const PLACEMENT_TOOLTIPS: Dictionary[String, String] = {
	"brush": "Paint",
	"block": "Block Placement",
	"polygon": "Polygon",
	"path": "Path",
	"telescoping": "Telescoping",
}


@export_group("Tool rail")
@export var _select_button: Button
@export var _brush_button: Button
@export var _move_button: Button
@export var _rotate_button: Button
@export var _scale_button: Button
@export var _place_button: Button
@export var _poly_edit_button: Button
@export var _poly_add_button: Button
@export var _poly_cut_button: Button
@export var _topline_button: Button

@export_group("Edit ops")
@export var _selection_op_buttons: Array[Button]

@export_group("History")
@export var _undo_button: Button
@export var _redo_button: Button

@export_group("Clipboard")
@export var _paste_button: Button

@export_group("Properties")
@export var _properties_button: Button

@export_group("Panels")
@export var _panel_buttons: Array[Button]
@export var _panel_ids: Array[StringName]


var _tool_buttons: Dictionary[String, Button] = {}
var _poly_buttons: Array[Button] = []


func setup() -> void:
	_tool_buttons = {
		"select": _select_button,
		"brush": _brush_button,
		"move": _move_button,
		"rotate": _rotate_button,
		"scale": _scale_button,
		"place": _place_button,
		"polygonedit": _poly_edit_button,
		"polygonadd": _poly_add_button,
		"polygoncut": _poly_cut_button,
		"topline": _topline_button,
	}
	_poly_buttons = [_poly_edit_button, _poly_add_button, _poly_cut_button, _topline_button]
	var tools: LDToolHandler = LD.get_tool_handler()
	if tools and not tools.tool_changed.is_connected(_on_tool_changed):
		tools.tool_changed.connect(_on_tool_changed)
	var viewport: LDViewport = LD.get_editor_viewport()
	if viewport and not viewport.selection_changed.is_connected(_on_selection_changed):
		viewport.selection_changed.connect(_on_selection_changed)
	var windows: LDUIWindowHandler = LD.get_ui().get_window_handler()
	if windows and not windows.active_changed.is_connected(_on_active_window_changed):
		windows.active_changed.connect(_on_active_window_changed)
	var history: LDHistoryHandler = LD.get_history_handler()
	if history and not history.history_changed.is_connected(_on_history_changed):
		history.history_changed.connect(_on_history_changed)
	var clipboard: LDClipboardHandler = LD.get_clipboard_handler()
	if clipboard and not clipboard.clipboard_changed.is_connected(_on_clipboard_changed):
		clipboard.clipboard_changed.connect(_on_clipboard_changed)
	var objects: LDObjectHandler = LD.get_object_handler()
	if objects and not objects.selected_object_changed.is_connected(_on_selected_object_changed):
		objects.selected_object_changed.connect(_on_selected_object_changed)
	var stamps: LDStampHandler = LD.get_stamp_handler()
	if stamps and not stamps.armed_stamp_changed.is_connected(_on_armed_stamp_changed):
		stamps.armed_stamp_changed.connect(_on_armed_stamp_changed)
	var current: LDTool = tools.get_selected_tool() if tools else null
	_on_tool_changed(current.get_tool_name() if current else "select")
	_on_selection_changed(viewport.get_selected_objects() if viewport else [] as Array[LDObject])
	_on_active_window_changed(&"")
	_on_history_changed()
	_on_clipboard_changed()
	_on_selected_object_changed(objects.get_selected_object() if objects else null)
	_on_armed_stamp_changed(stamps.get_armed_stamp() if stamps else null)


#region Active highlight

func _on_tool_changed(tool_name: String) -> void:
	var key: String = tool_name.to_lower().remove_char(95)
	var is_placement: bool = PLACEMENT_ICONS.has(key)
	for name: String in _tool_buttons:
		_set_active(_tool_buttons.get(name), name == key or (name == "brush" and is_placement))


func _on_active_window_changed(id: StringName) -> void:
	for i: int in mini(_panel_buttons.size(), _panel_ids.size()):
		_set_active(_panel_buttons[i], _panel_ids[i] == id)


func _set_active(button: Button, active: bool) -> void:
	if button == null:
		return
	if active:
		GDSS.add_class(button, ACTIVE_CLASS)
	else:
		GDSS.remove_class(button, ACTIVE_CLASS)

#endregion


#region Placement button

func _on_selected_object_changed(obj: GameObject) -> void:
	if _brush_button == null:
		return
	var key: String = obj.get_placement_tool().to_lower() if obj else ""
	if not PLACEMENT_ICONS.has(key):
		key = "brush"
	_brush_button.icon = PLACEMENT_ICONS.get(key)
	_brush_button.tooltip_text = PLACEMENT_TOOLTIPS.get(key)

#endregion


#region Contextual visibility / enable

func _on_selection_changed(objects: Array[LDObject]) -> void:
	var has_selection: bool = not objects.is_empty()
	for button: Button in _selection_op_buttons:
		_set_disabled(button, not has_selection)
	var is_polygon: bool = objects.size() == 1 and objects.front() is LDObjectPolygon
	var supports_topline: bool = false
	if is_polygon:
		var poly: LDObjectPolygon = objects.front() as LDObjectPolygon
		supports_topline = poly.polygon_data != null and poly.polygon_data.line_mode == PolygonData.LineMode.TOPLINE
	for button: Button in _poly_buttons:
		if button:
			button.visible = is_polygon
	_set_disabled(_topline_button, is_polygon and not supports_topline)
	var any_rotatable: bool = false
	var any_scalable: bool = false
	for obj: LDObject in objects:
		for prop: LDProperty in obj.get_properties():
			var prop_key: String = String(prop.key)
			if prop_key.get_slice(":", 0) == "rotation":
				any_rotatable = true
			if prop_key == "scale":
				any_scalable = true
	if _rotate_button:
		_rotate_button.visible = any_rotatable
	if _scale_button:
		_scale_button.visible = any_scalable
	_set_disabled(_properties_button, not LD.get_object_handler().has_editable_properties(objects))


func _on_history_changed() -> void:
	var history: LDHistoryHandler = LD.get_history_handler()
	_set_disabled(_undo_button, not (history and history.can_undo()))
	_set_disabled(_redo_button, not (history and history.can_redo()))


func _on_clipboard_changed() -> void:
	var clipboard: LDClipboardHandler = LD.get_clipboard_handler()
	_set_disabled(_paste_button, not (clipboard and clipboard.has_content()))


func _on_armed_stamp_changed(stamp: LDStamp) -> void:
	if _place_button:
		_place_button.visible = stamp != null


func _set_disabled(button: Button, value: bool) -> void:
	if button == null or button.disabled == value:
		return
	button.disabled = value
	GDSS.refresh(button)

#endregion
