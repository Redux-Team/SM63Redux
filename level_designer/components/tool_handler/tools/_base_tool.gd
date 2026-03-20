@warning_ignore_start("unused_private_class_variable", "unused_parameter")
@abstract class_name LDTool
extends Node


var viewport: LDViewport:
	get:
		return LD.get_editor_viewport()

var _enabled: bool = false


@abstract func get_tool_name() -> String
@abstract func _on_ready() -> void


func _ready() -> void:
	LD.get_editor_viewport().viewport_input.connect(_on_viewport_input)
	_on_ready()


func _on_enable() -> void:
	viewport._viewport_input.mouse_default_cursor_shape = get_cursor_shape()


func _on_disable() -> void:
	viewport._viewport_input.mouse_default_cursor_shape = Control.CURSOR_ARROW


## Override to define the cursor shape for this tool.
func get_cursor_shape() -> Control.CursorShape:
	return Control.CURSOR_ARROW


## Uses the viewport's input priority via [signal LDViewport.viewport_input]
func _on_viewport_input(event: InputEvent) -> void:
	pass


func get_tool_handler() -> LDToolHandler:
	return owner


func get_editor_viewport() -> LDViewport:
	return LDViewport._get_instance()


func is_active() -> bool:
	return get_tool_handler().get_selected_tool() == self
