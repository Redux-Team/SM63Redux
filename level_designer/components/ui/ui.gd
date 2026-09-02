class_name LDUI
extends Node

## Facade over the level designer's UI. Holds no logic itself - every concern lives in a
## dedicated handler, reachable via the get_*_handler() accessors (mirrors how the LD
## singleton exposes its subsystem handlers).


## Chrome and windows are authored at 1:1 for touch and shrunk on desktop, where the
## game's 640x360 stretch would otherwise blow the editor up to fill the screen.
const DESKTOP_SCALE: float = 0.8
const TOUCH_SCALE: float = 1.0

@export var _chrome: Control
@export var _top_bar_left: Control
@export var _top_bar_right: Control
@export_group("Handlers")
@export var _window_handler: LDUIWindowHandler
@export var _viewport_handler: LDUIViewportHandler
@export var _toolbar_handler: LDUIToolbarHandler
@export var _file_handler: LDUIFileHandler
@export var _hotbar_handler: LDUIHotbarHandler
@export var _chrome_handler: LDUIChromeHandler


## Uniform scale for every editor surface. One knob: chrome reads it here, windows read it
## when they pop in.
static func get_ui_scale() -> float:
	var touch: bool = Device.is_mobile() or Singleton.get_input_handler().is_using_touch()
	return TOUCH_SCALE if touch else DESKTOP_SCALE


func _enter_tree() -> void:
	get_viewport().size_changed.connect(_rescale_chrome)


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_rescale_chrome)


func setup() -> void:
	# Handlers that touch level/area state wait until everything is ready.
	_toolbar_handler.setup()
	_file_handler.setup()
	_hotbar_handler.setup()
	_chrome_handler.setup()
	_rescale_chrome()
	# Deferred so the handlers above are wired first: the browser announces itself as it is
	# built, and the hotbar has to be listening by then.
	_window_handler.prewarm.call_deferred(LDUIWindowHandler.OBJECT_BROWSER)


## Chrome anchors full-rect, so shrinking it would shrink the region its rails anchor to.
## Grow the rect by the inverse of the scale instead: it renders smaller but still spans
## the whole screen.
func _rescale_chrome() -> void:
	var ui_scale: float = get_ui_scale()
	var view: Vector2 = get_viewport().get_visible_rect().size
	_chrome.scale = Vector2(ui_scale, ui_scale)
	_chrome.offset_right = view.x * (1.0 / ui_scale - 1.0)
	_chrome.offset_bottom = view.y * (1.0 / ui_scale - 1.0)


## The two chrome bars the song announcement has to fit between.
func get_top_bar_left() -> Control:
	return _top_bar_left


func get_top_bar_right() -> Control:
	return _top_bar_right


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
