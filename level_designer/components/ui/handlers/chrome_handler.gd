class_name LDUIChromeHandler
extends Node

## Keeps the on-screen toolbar chrome reactive to editor state:
##   • highlights the active tool button (GDSS "Active" class) as the tool changes,
##   • highlights the panel-toggle button whose window is open,
##   • shows the polygon tool buttons ONLY while a polygon object is selected
##     (mirrors LDPolygonEditTool's own precondition so the button never offers a
##     tool that would instantly bounce back to Select),
##   • enables/disables the edit-op buttons by whether there's a selection.
## Reached via LD.get_ui().get_chrome_handler(). Pure presentation — the buttons'
## own pressed/toggled signals still drive the handlers that do the work.

const ACTIVE_CLASS: StringName = &"Active"


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

@export_group("Edit ops")
## The contextual edit-op buttons (Cut/Copy/Duplicate/Delete/Deselect/MoveToFront/
## MoveToBack/CreateStamp) — disabled when there is no selection. Paste is excluded
## so Ctrl+V keeps working from the clipboard regardless of selection.
@export var _selection_op_buttons: Array[Button]

@export_group("Panels")
## Panel-toggle buttons, parallel to _panel_ids (same order). The matching button
## gets the Active class while its window is open.
@export var _panel_buttons: Array[Button]
## Window ids (LDUIWindowHandler.*), parallel to _panel_buttons.
@export var _panel_ids: Array[StringName]


var _tool_buttons: Dictionary[String, Button] = {}
var _poly_buttons: Array[Button] = []


## Called by LDUI once the level designer is fully ready.
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
	}
	_poly_buttons = [_poly_edit_button, _poly_add_button, _poly_cut_button]

	var tools: LDToolHandler = LD.get_tool_handler()
	if tools and not tools.tool_changed.is_connected(_on_tool_changed):
		tools.tool_changed.connect(_on_tool_changed)

	var viewport: LDViewport = LD.get_editor_viewport()
	if viewport and not viewport.selection_changed.is_connected(_on_selection_changed):
		viewport.selection_changed.connect(_on_selection_changed)

	var windows: LDUIWindowHandler = LD.get_ui().get_window_handler()
	if windows and not windows.active_changed.is_connected(_on_active_window_changed):
		windows.active_changed.connect(_on_active_window_changed)

	# Prime the initial state.
	var current: LDTool = tools.get_selected_tool() if tools else null
	_on_tool_changed(current.get_tool_name() if current else "select")
	_on_selection_changed(viewport.get_selected_objects() if viewport else [] as Array[LDObject])
	_on_active_window_changed(&"")


#region Active highlight

func _on_tool_changed(tool_name: String) -> void:
	var key: String = tool_name.to_lower().remove_char(95)
	for name: String in _tool_buttons:
		_set_active(_tool_buttons[name], name == key)


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


#region Contextual visibility / enable

func _on_selection_changed(objects: Array[LDObject]) -> void:
	var has_selection: bool = not objects.is_empty()
	for button: Button in _selection_op_buttons:
		if button:
			button.disabled = not has_selection

	# Polygon tools apply only to a single selected polygon object.
	var is_polygon: bool = objects.size() == 1 and objects[0] is LDObjectPolygon
	for button: Button in _poly_buttons:
		if button:
			button.visible = is_polygon

#endregion
