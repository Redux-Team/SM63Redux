@tool
class_name EditorStateMachineGraphNode
extends GraphNode

signal script_changed_in_editor

const BASE_CLASS: String = "State"

var state_name: String:
	set(sn):
		if _title_label:
			_title_label.text = sn
		state_name = sn

var _attached_script: Script
var _title_label: Label
var _title_input: LineEdit
var _script_button: Button
var _clear_button: Button


func _ready() -> void:
	_title_label = Label.new()
	_title_label.mouse_filter = Control.MOUSE_FILTER_PASS
	_title_input = LineEdit.new()
	_title_input.hide()
	
	var hb: HBoxContainer = get_titlebar_hbox()
	hb.get_child(0).queue_free()
	hb.add_child(_title_label)
	hb.add_child(_title_input)
	
	_title_label.text = state_name
	_title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_label.gui_input.connect(_on_title_input)
	_title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	_title_input.text_submitted.connect(finish_name_edit)
	_title_input.focus_exited.connect(finish_name_edit)
	_title_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title_input.alignment = HORIZONTAL_ALIGNMENT_CENTER
	
	var script_row: HBoxContainer = HBoxContainer.new()
	script_row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(script_row)
	
	_script_button = Button.new()
	_script_button.text = "Attach Script"
	_script_button.icon = EditorInterface.get_editor_theme().get_icon(&"ScriptCreate", &"EditorIcons")
	_script_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_script_button.pressed.connect(_on_script_button_pressed)
	_script_button.set_drag_forwarding(Callable(), _can_drop_script, _drop_script)
	script_row.add_child(_script_button)
	
	_clear_button = Button.new()
	_clear_button.icon = EditorInterface.get_editor_theme().get_icon(&"Remove", &"EditorIcons")
	_clear_button.visible = false
	_clear_button.theme_type_variation = &"FlatButton"
	_clear_button.pressed.connect(_on_clear_button_pressed)
	script_row.add_child(_clear_button)


func start_name_edit() -> void:
	var release: InputEventMouseButton = InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.pressed = false
	get_viewport().push_input(release)
	
	_title_label.hide()
	_title_input.text = state_name
	_title_input.caret_column = 99
	_title_input.show()
	release_focus()
	_title_input.grab_focus()


func finish_name_edit(_a: String = "") -> void:
	if _title_input.text:
		state_name = _title_input.text
	
	_title_input.hide()
	_title_label.show()


func get_script_path() -> String:
	if _attached_script == null:
		return ""
	return _attached_script.resource_path


func apply_script_from_path(path: String) -> void:
	var script: Script = load(path)
	if _validate_script(script):
		_apply_script(script)


func _on_title_input(e: InputEvent) -> void:
	if e is InputEventMouseButton \
			and e.button_index == MOUSE_BUTTON_LEFT \
			and e.double_click \
			and e.is_pressed():
		start_name_edit()


func _on_script_button_pressed() -> void:
	EditorInterface.popup_quick_open(_on_quick_open_selected, [&"Script"])


func _on_quick_open_selected(path: String) -> void:
	if path.is_empty():
		return
	
	var script: Script = load(path)
	if not _validate_script(script):
		_show_invalid_script_dialog()
		return
	
	_apply_script(script)


func _on_clear_button_pressed() -> void:
	_attached_script = null
	_script_button.text = "Attach Script"
	_script_button.icon = EditorInterface.get_editor_theme().get_icon(&"ScriptCreate", &"EditorIcons")
	_clear_button.visible = false
	script_changed_in_editor.emit()


func _can_drop_script(_at_position: Vector2, data: Variant) -> bool:
	if not data is Dictionary:
		return false
	if not data.get("type", "") == "files":
		return false
	
	var files: Array = data.get("files", [])
	if files.size() != 1:
		return false
	
	var path: String = files[0]
	if not path.ends_with(".gd"):
		return false
	
	return _validate_script(load(path))


func _drop_script(_at_position: Vector2, data: Variant) -> void:
	var files: Array = data.get("files", [])
	_apply_script(load(files[0]))


func _validate_script(script: Script) -> bool:
	if script == null:
		return false
	
	var base: Script = script
	while base != null:
		if base.get_global_name() == BASE_CLASS:
			return true
		base = base.get_base_script()
	
	return false


func _apply_script(script: Script) -> void:
	_attached_script = script
	
	var class_name_str: StringName = script.get_global_name()
	var icon_name: StringName = class_name_str if class_name_str != &"" else &"GDScript"
	var theme: Theme = EditorInterface.get_editor_theme()
	
	_script_button.text = script.resource_path.get_file().get_file()
	_script_button.tooltip_text = script.resource_path
	
	if theme.has_icon(icon_name, &"EditorIcons"):
		_script_button.icon = theme.get_icon(icon_name, &"EditorIcons")
	else:
		_script_button.icon = theme.get_icon(&"GDScript", &"EditorIcons")
	
	_clear_button.visible = true
	script_changed_in_editor.emit()


func _show_invalid_script_dialog() -> void:
	var dialog: AcceptDialog = AcceptDialog.new()
	dialog.title = "Invalid Script"
	dialog.dialog_text = "Script must extend %s." % BASE_CLASS
	dialog.confirmed.connect(dialog.queue_free)
	EditorInterface.get_base_control().add_child(dialog)
	dialog.popup_centered()
