class_name LDUI
extends LDComponent

@export var _obj_browser_window: LDWindow
@export var _canvas_layer: CanvasLayer


func get_canvas_layer() -> CanvasLayer:
	return _canvas_layer


func get_object_browser_window() -> LDWindow:
	return _obj_browser_window


func _on_ready() -> void:
	(_obj_browser_window.get_content_ref() as LDObjectBrowser).category_changed.connect(func(n: String) -> void:
		_obj_browser_window.title = "Objects - " + (n if n else "All")
	)


func _on_input(_event: InputEvent) -> void:
	pass


func _input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.keycode == KEY_SPACE and event.is_pressed() and not event.is_echo():
			_toggle_object_browser()


func _toggle_object_browser() -> void:
	if get_object_browser_window().visible:
		get_object_browser_window().popout()
		remove_input_priority()
	else:
		get_object_browser_window().popin()
		set_input_priority()
