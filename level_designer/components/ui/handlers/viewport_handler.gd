class_name LDUIViewportHandler
extends Node

## Owns the editor-viewport display toggles (parallaxing + layer ghosting) and keeps
## their toolbar buttons in sync. Reached via LD.get_ui().get_viewport_handler().

@export var _parallaxing_button: Button
@export var _ghosting_button: Button


var _parallaxing_enabled: bool = false
var _ghosting_enabled: bool = false


func is_parallaxing_enabled() -> bool:
	return _parallaxing_enabled


func is_ghosting_enabled() -> bool:
	return _ghosting_enabled


func set_parallaxing_enabled(enabled: bool) -> void:
	_parallaxing_enabled = enabled
	_parallaxing_button.set_pressed_no_signal(enabled)
	for layer: LDLayer in LD.get_area().layers:
		layer.is_parallaxing = enabled
	LD.get_area().refresh_layer_visuals()
	LD.get_editor_viewport().refresh()


func set_ghosting_enabled(enabled: bool) -> void:
	_ghosting_enabled = enabled
	_ghosting_button.set_pressed_no_signal(enabled)
	LD.get_editor_viewport().clear_selection()
	LD.get_area().refresh_layer_visuals()
