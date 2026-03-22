class_name LDUI
extends LDComponent


@export var _canvas_layer: CanvasLayer
@export_group("Windows")
@export var _obj_browser_window: LDWindow
@export var _object_property_window: LDWindow
@export_group("File Dialogs")
@export var _save_file_dialog: FileDialog
@export var _load_file_dialog: FileDialog


func _on_ready() -> void:
	var browser: LDObjectBrowser = _obj_browser_window.get_content_ref() as LDObjectBrowser
	browser.category_changed.connect(func(n: String) -> void:
		_obj_browser_window.title = "Objects - " + (n if n else "All")
	)
	browser.hide_request.connect(func() -> void:
		_obj_browser_window.popout()
	)
	
	_save_file_dialog.filters = PackedStringArray([
		"*.63r.lvl;63 Redux Level",
		"*.json;JSON Level"
	])
	_load_file_dialog.filters = PackedStringArray([
		"*.63r.lvl;63 Redux Level",
		"*.json;JSON Level"
	])


func _input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.is_pressed() or event.is_echo():
		return
	
	match event.keycode:
		KEY_SPACE:
			_toggle_window(_obj_browser_window)
		KEY_P:
			if not LD.get_object_handler().get_placed_selection().is_empty():
				_toggle_window(_object_property_window)


func _on_input(_event: InputEvent) -> void:
	pass


func get_canvas_layer() -> CanvasLayer:
	return _canvas_layer


func get_object_browser_window() -> LDWindow:
	return _obj_browser_window


func get_object_properties_window() -> LDWindow:
	return _object_property_window


func _toggle_window(window: LDWindow) -> void:
	if window.visible:
		window.popout()
	else:
		window.popin()


func _on_save_file_selected(path: String) -> void:
	var handler: LDSaveLoadHandler = LD.get_save_load_handler()
	var err: Error
	if path.get_extension() == "json":
		err = handler.save_json(path)
	else:
		err = handler.save_binary(path)
	if err != OK:
		push_error("Failed to save level: " + error_string(err))


func _on_load_file_selected(path: String) -> void:
	var handler: LDSaveLoadHandler = LD.get_save_load_handler()
	var err: Error
	if path.ends_with(".json"):
		err = handler.load_json(path)
	else:
		err = handler.load_binary(path)
	if err != OK:
		push_error("Failed to load level: " + error_string(err))


func _on_object_browser_button_pressed() -> void:
	_toggle_window(_obj_browser_window)


func _on_properties_button_pressed() -> void:
	_toggle_window(_object_property_window)


func _on_select_button_pressed() -> void:
	LD.get_tool_handler().select_tool("select")


func _on_brush_button_pressed() -> void:
	LD.get_tool_handler().select_tool("brush")


func _on_move_button_pressed() -> void:
	LD.get_tool_handler().select_tool("move")


func _on_reset_button_pressed() -> void:
	LD.get_editor_viewport().refocus_camera(Vector2.ZERO, Vector2.ONE)


func _on_delete_button_pressed() -> void:
	LD.get_object_handler().delete_placed_selection()


func _on_save_button_pressed() -> void:
	_save_file_dialog.popup_centered()


func _on_load_button_pressed() -> void:
	_load_file_dialog.popup_centered()


func _on_rotate_button_pressed() -> void:
	LD.get_tool_handler().select_tool("rotate")


func _on_test_button_pressed() -> void:
	Singleton.set_meta("playtest", LD.get_save_load_handler().get_level_data())
	get_tree().change_scene_to_file("uid://ctssku6r3gx0a")


func _on_poly_edit_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_edit")


func _on_poly_add_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_add")


func _on_poly_cut_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_cut")
