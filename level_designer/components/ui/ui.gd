class_name LDUI
extends LDComponent


@export var _canvas_layer: CanvasLayer
@export_group("Windows")
@export var _obj_browser_window: LDWindow
@export var _object_property_window: LDWindow
@export var _layer_properties_window: LDWindow
@export_group("File Dialogs")
@export var _save_file_dialog: FileDialog
@export var _load_file_dialog: FileDialog
@export var _reset_level_dialog: ConfirmationDialog
@export_group("Layer")
@export var _layer_down: Button
@export var _layer_num: Label
@export var _layer_up: Button
@export var _parallaxing_button: Button
@export var _ghosting_button: Button


var parallaxing_enabled: bool = false
var ghosting_enabled: bool = false

var viewport: LDViewport:
	get():
		return LD.get_editor_viewport()


func _on_ready() -> void:
	var browser: LDObjectBrowser = _obj_browser_window.get_content_ref() as LDObjectBrowser
	
	_layer_num.text = str(LD.get_area().get_active_layer_index())
	
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
		LD.get_input_handler().remove_input_priority(self)
	else:
		LD.get_input_handler().set_input_priority(self)
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


func _on_layer_properties_pressed() -> void:
	_toggle_window(_layer_properties_window)


func _on_select_button_pressed() -> void:
	LD.get_tool_handler().select_tool("select")


func _on_brush_button_pressed() -> void:
	LD.get_tool_handler().select_tool("brush")


func _on_move_button_pressed() -> void:
	LD.get_tool_handler().select_tool("move")


func _on_reset_cam_button_pressed() -> void:
	var player: LDObject = LD.get_area().find_object_by_id("player_mario", 0)
	viewport.refocus_camera(player.position, Vector2.ONE)


func _on_delete_button_pressed() -> void:
	LD.get_object_handler().delete_placed_selection()


func _on_save_button_pressed() -> void:
	_save_file_dialog.popup_centered()


func _on_load_button_pressed() -> void:
	_load_file_dialog.popup_centered()


func _on_reset_button_pressed() -> void:
	_reset_level_dialog.popup_centered()


func _on_rotate_button_pressed() -> void:
	LD.get_tool_handler().select_tool("rotate")


func _on_test_server_button_pressed() -> void:
	#Singleton.get_multiplayer_handler().start_server()
	Singleton.set_meta("playtest", LD.get_save_load_handler().get_level_data())
	
	LD.get_save_load_handler().save_session()
	
	get_tree().change_scene_to_file("uid://ctssku6r3gx0a")


func _on_test_client_button_pressed() -> void:
	Singleton.get_multiplayer_handler().start_client()
	Singleton.set_meta("playtest", LD.get_save_load_handler().get_level_data())
	
	get_tree().change_scene_to_file("uid://ctssku6r3gx0a")


func _on_poly_edit_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_edit")


func _on_poly_add_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_add")


func _on_poly_cut_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_cut")


func _on_move_to_front_button_pressed() -> void:
	var objs: Array[LDObject] = viewport.get_selected_objects()
	for obj: LDObject in objs:
		obj.get_parent().move_child(obj, -1)


func _on_move_to_back_button_pressed() -> void:
	var objs: Array[LDObject] = viewport.get_selected_objects()
	for obj: LDObject in objs:
		obj.get_parent().move_child(obj, 0)


func set_parallaxing(toggled_on: bool) -> void:
	parallaxing_enabled = toggled_on
	_parallaxing_button.set_pressed_no_signal(toggled_on)
	for layer: LDLayer in LD.get_area().layers:
		layer.is_parallaxing = toggled_on
	LD.get_area().refresh_layer_visuals()
	LD.get_editor_viewport().refresh()


func set_ghosting(toggled_on: bool) -> void:
	ghosting_enabled = toggled_on
	_ghosting_button.set_pressed_no_signal(toggled_on)
	LD.get_editor_viewport().clear_selection()
	LD.get_area().refresh_layer_visuals()


func _on_reset_level_dialog_confirmed() -> void:
	LD.get_save_load_handler().reset_level()


func _on_deselect_button_pressed() -> void:
	LD.get_editor_viewport().clear_selection()


func _on_scale_button_pressed() -> void:
	LD.get_tool_handler().select_tool("scale")


func _on_cut_button_pressed() -> void:
	LD.get_clipboard_handler().cut()


func _on_copy_button_pressed() -> void:
	LD.get_clipboard_handler().copy()


func _on_paste_button_pressed() -> void:
	const OFFSET: Vector2 = Vector2(24, -24)
	var camera_pos: Vector2 = LD.get_editor_viewport().camera_position
	LD.get_clipboard_handler().paste_absolute(camera_pos + OFFSET)


func _on_duplicate_button_pressed() -> void:
	LD.get_clipboard_handler().duplicate_objects()


func _on_layer_down_pressed() -> void:
	_set_layer(-1, true)


func _on_layer_up_pressed() -> void:
	_set_layer(1, true)


func _set_layer(index: int, increment: bool = false) -> void:
	if increment:
		LD.get_area().set_active_layer(LD.get_area().get_active_layer_index() + index)
	else:
		LD.get_area().set_active_layer(index)
	
	if viewport.get_selected_objects().size() > 0:
		var selection: Array[LDObject] = viewport.get_selected_objects()
		LD.get_area().move_objects_to_layer(selection, index)
	
	_layer_num.text = str(LD.get_area().get_active_layer_index())
