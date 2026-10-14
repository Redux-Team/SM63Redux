class_name LDPlaceTool
extends LDTool

@export var preview_root: Node2D
@export var preview_modulate: Color = Color(1.0, 1.0, 1.0, 0.5)

var _preview: GameObject


func _setup() -> void:
	editor.tool_handler.armed_changed.connect(_on_armed_changed.unbind(1))


func _activate() -> void:
	_refresh_preview()


func _deactivate() -> void:
	_clear_preview()


func _process(_delta: float) -> void:
	var layer: LevelLayer = editor.level_handler.active_layer
	if _preview == null or layer == null:
		return
	
	preview_root.global_transform = layer.get_objects_root().get_global_transform()
	_preview.position = get_snapped_mouse()


func _tool_input(event: InputEvent, _world_position: Vector2) -> bool:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button == null or mouse_button.button_index != MOUSE_BUTTON_LEFT or not mouse_button.pressed or editor.tool_handler.armed == null:
		return false
	
	var object: GameObject = create_object(get_snapped_mouse())
	editor.object_handler.add_objects([object], editor.level_handler.active_layer, "Place %s" % editor.tool_handler.armed.display_name, false)
	return true


func get_snapped_mouse() -> Vector2:
	return editor.viewport_handler.snap(editor.viewport_handler.get_layer_mouse(editor.level_handler.active_layer))


func create_object(local_position: Vector2) -> GameObject:
	var object: GameObject = editor.object_handler.spawn(editor.tool_handler.armed.id, local_position)
	for property: ObjectProperty in object.properties:
		if editor.tool_handler.should_randomize(property):
			object.set_value(property.key, property.random_value())
	
	return object


func _on_armed_changed() -> void:
	if is_active():
		_refresh_preview()


func _refresh_preview() -> void:
	_clear_preview()
	if editor.tool_handler.armed == null:
		return
	
	_preview = editor.object_handler.spawn(editor.tool_handler.armed.id, Vector2.ZERO)
	_preview.modulate = preview_modulate
	preview_root.add_child(_preview)


func _clear_preview() -> void:
	if _preview:
		_preview.free()
		_preview = null
