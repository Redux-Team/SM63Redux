@warning_ignore_start("unused_private_class_variable", "unused_parameter")
@abstract class_name LDTool
extends Node

var viewport: LDViewport:
	get:
		return LD.get_editor_viewport()

var _enabled: bool = false
var _preview_object: LDObject


@abstract func get_tool_name() -> String
@abstract func _on_ready() -> void


func _ready() -> void:
	LD.get_editor_viewport().viewport_input.connect(_on_viewport_input)
	_on_ready()


func _on_enable() -> void:
	viewport._viewport_input.mouse_default_cursor_shape = get_cursor_shape()


func _on_disable() -> void:
	viewport._viewport_input.mouse_default_cursor_shape = Control.CURSOR_ARROW
	_destroy_preview()


func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_ARROW


func set_cursor_shape(cursor_shape: Control.CursorShape) -> void:
	viewport._viewport_input.mouse_default_cursor_shape = cursor_shape


func _on_viewport_input(event: InputEvent) -> void:
	pass


func get_tool_handler() -> LDToolHandler:
	return owner


func get_editor_viewport() -> LDViewport:
	return LDViewport._get_instance()


func is_active() -> bool:
	return get_tool_handler().get_selected_tool() == self


func spawn_preview(obj: GameObject) -> LDObject:
	_destroy_preview()
	if not obj or not obj.ld_editor_instance:
		return null
	_preview_object = obj.ld_editor_instance.instantiate() as LDObject
	_preview_object.is_preview = true
	_preview_object.init_properties(obj)
	viewport.add_object(_preview_object)
	return _preview_object


func get_preview() -> LDObject:
	return _preview_object if is_instance_valid(_preview_object) else null


func has_preview() -> bool:
	return is_instance_valid(_preview_object)


func release_preview() -> LDObject:
	var obj: LDObject = _preview_object
	_preview_object = null
	return obj


func _destroy_preview() -> void:
	if is_instance_valid(_preview_object):
		_preview_object.queue_free()
	_preview_object = null
