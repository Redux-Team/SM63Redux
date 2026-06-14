class_name LDUI
extends LDComponent

## Facade over the level designer's UI. Holds no logic itself — every concern lives in a
## dedicated handler, reachable via the get_*_handler() accessors (mirrors how the LD
## singleton exposes its subsystem handlers).


@export var _canvas_layer: CanvasLayer
@export_group("Handlers")
@export var _window_handler: LDUIWindowHandler
@export var _viewport_handler: LDUIViewportHandler
@export var _toolbar_handler: LDUIToolbarHandler
@export var _file_handler: LDUIFileHandler
@export var _hotbar_handler: LDUIHotbarHandler


func _on_ready() -> void:
	# Handlers that touch level/area state wait until everything is ready.
	_toolbar_handler.setup()
	_file_handler.setup()
	_hotbar_handler.setup()


func get_window_handler() -> LDUIWindowHandler:
	return _window_handler


func get_viewport_handler() -> LDUIViewportHandler:
	return _viewport_handler


func get_toolbar_handler() -> LDUIToolbarHandler:
	return _toolbar_handler


func get_file_handler() -> LDUIFileHandler:
	return _file_handler


func get_hotbar_handler() -> LDUIHotbarHandler:
	return _hotbar_handler


func get_canvas_layer() -> CanvasLayer:
	return _canvas_layer
