class_name LDUI
extends LDComponent


@export var _canvas_layer: CanvasLayer
@export_group("Windows")
@export var _obj_browser_window: LDWindow
@export var _object_property_window: LDWindow


func _on_ready() -> void:
	var browser: LDObjectBrowser = _obj_browser_window.get_content_ref() as LDObjectBrowser
	browser.category_changed.connect(func(n: String) -> void:
		_obj_browser_window.title = "Objects - " + (n if n else "All")
	)
	browser.hide_request.connect(func() -> void:
		_obj_browser_window.popout()
	)
	_obj_browser_window.popped_in.connect(_on_window_shown)
	_obj_browser_window.popped_out.connect(_on_window_hidden)
	
	_object_property_window.popped_in.connect(_on_window_shown)
	_object_property_window.popped_out.connect(_on_window_hidden)


func _input(event: InputEvent) -> void:
	if not LD.get_editor_viewport().has_input_priority():
		return
	
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


func _on_window_shown() -> void:
	set_input_priority()


func _on_window_hidden() -> void:
	remove_input_priority()
