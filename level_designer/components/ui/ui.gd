class_name LDUI
extends LDComponent

## Facade over the level designer's UI. Holds no logic itself - every concern lives in a
## dedicated handler, reachable via the get_*_handler() accessors (mirrors how the LD
## singleton exposes its subsystem handlers).


## The editor chrome is sized compact for desktop by default (scene values) and
## scaled UP on touch/mobile. Font size lives on the editor Theme so one property
## scales every label/button; button min-sizes scale in code and their icons
## follow automatically via expand_icon.
## Not a const: GDScript forbids mutating a const resource's properties, and we
## tweak default_font_size at runtime. It's still the shared cached instance the
## scenes reference, so the change propagates to all UI text.
var _editor_theme: Theme = preload("res://level_designer/ld_editor_theme.tres")
const DESKTOP_FONT_SIZE: int = 14
const MOBILE_FONT_SIZE: int = 18
const MOBILE_BUTTON_SCALE: float = 1.65
const MOBILE_MIN_TARGET: float = 44.0
const MOBILE_SEPARATION: int = 8

@export var _canvas_layer: CanvasLayer
@export_group("Handlers")
@export var _window_handler: LDUIWindowHandler
@export var _viewport_handler: LDUIViewportHandler
@export var _toolbar_handler: LDUIToolbarHandler
@export var _file_handler: LDUIFileHandler
@export var _hotbar_handler: LDUIHotbarHandler
@export var _chrome_handler: LDUIChromeHandler


func _on_ready() -> void:
	# Handlers that touch level/area state wait until everything is ready.
	_toolbar_handler.setup()
	_file_handler.setup()
	_hotbar_handler.setup()
	_chrome_handler.setup()
	_apply_responsive()


## Desktop keeps the compact scene sizing (so the chrome never runs off-screen).
## On touch/mobile, scale the whole chrome up: bigger tap targets, wider spacing,
## and a larger base font (via the shared editor Theme). Driven off
## Device.is_mobile() / live touch state — one hook adapts the entire UI.
func _apply_responsive() -> void:
	var touch: bool = Device.is_mobile() or Singleton.get_input_handler().is_using_touch()
	_editor_theme.default_font_size = MOBILE_FONT_SIZE if touch else DESKTOP_FONT_SIZE
	if touch:
		_scale_chrome(_canvas_layer)


func _scale_chrome(node: Node) -> void:
	for child: Node in node.get_children():
		if child is BaseButton:
			var control: Control = child as Control
			var size: Vector2 = control.custom_minimum_size
			control.custom_minimum_size = Vector2(
				maxf(size.x * MOBILE_BUTTON_SCALE, MOBILE_MIN_TARGET),
				maxf(size.y * MOBILE_BUTTON_SCALE, MOBILE_MIN_TARGET))
		elif child is BoxContainer:
			(child as BoxContainer).add_theme_constant_override(&"separation", MOBILE_SEPARATION)
		_scale_chrome(child)


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


func get_chrome_handler() -> LDUIChromeHandler:
	return _chrome_handler


func get_canvas_layer() -> CanvasLayer:
	return _canvas_layer
