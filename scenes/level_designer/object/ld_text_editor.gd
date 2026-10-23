class_name LDTextEditor
extends LDComponent

@export var text_edit: TextEdit

var _object: GameObject
var _display: TextDisplay
var _key: StringName


static func get_text_property(object: GameObject) -> ObjectProperty:
	for property: ObjectProperty in object.properties:
		if (
				property.bbcode
				and not property.targets.is_empty()
				and object.get_node_or_null(property.targets.front()) is TextDisplay
		):
			return property
	
	return null


func _process(_delta: float) -> void:
	if not is_instance_valid(_object) or not _object.is_inside_tree():
		cancel()
		return
	
	_follow()


func _setup() -> void:
	text_edit.hide()
	text_edit.focus_exited.connect(finish)
	text_edit.gui_input.connect(_on_text_input)
	text_edit.resized.connect(_follow)
	set_process(false)


func begin(object: GameObject) -> bool:
	var property: ObjectProperty = get_text_property(object)
	if property == null:
		return false
	
	finish()
	_object = object
	_key = property.key
	_display = object.get_node(property.targets.front()) as TextDisplay
	text_edit.add_theme_font_override(&"font", _display.get_theme_font(&"normal_font"))
	text_edit.add_theme_font_size_override(
			&"font_size",
			_display.get_theme_font_size(&"normal_font_size"),
	)
	text_edit.text = str(object.get_value(_key))
	_display.hide()
	text_edit.show()
	text_edit.grab_focus()
	text_edit.select_all()
	set_process(true)
	_follow()
	return true


func finish() -> void:
	if _object == null:
		return
	
	var object: GameObject = _object
	_object = null
	set_process(false)
	text_edit.hide()
	_display.show()
	if is_instance_valid(object) and text_edit.text != str(object.get_value(_key)):
		editor.object_handler.set_values([object], _key, text_edit.text)


func cancel() -> void:
	if _object:
		text_edit.text = str(_object.get_value(_key))
	finish()


func _follow() -> void:
	if _object == null:
		return
	
	var to_screen: Transform2D = \
			editor.world.get_canvas_transform() * _display.get_global_transform()
	text_edit.rotation = to_screen.get_rotation()
	text_edit.position = to_screen * _display.get_theme_stylebox(&"normal").get_offset()


func _on_text_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key == null or not key.pressed:
		return
	
	if key.keycode == KEY_ESCAPE:
		cancel()
		text_edit.accept_event()
	elif key.keycode == KEY_ENTER and key.ctrl_pressed:
		text_edit.release_focus()
		text_edit.accept_event()
