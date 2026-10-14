class_name LDInterfaceHandler
extends LDHandler

signal panel_changed(panel: LDPanel)

const DESKTOP_SCALE: float = 0.8
const TOUCH_SCALE: float = 1.0

@export var hud: Control
@export var window: LDWindow

var current_panel: LDPanel


func _setup() -> void:
	window.closed.connect(_on_window_closed)
	_rescale()


func _enter_tree() -> void:
	get_viewport().size_changed.connect(_rescale)
	if is_node_ready():
		_rescale()


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(_rescale)


func _unhandled_input(event: InputEvent) -> void:
	if current_panel and editor.is_shortcut(event, &"ld_back"):
		hide_panel()
		get_viewport().set_input_as_handled()


func get_ui_scale() -> float:
	return TOUCH_SCALE if Device.is_mobile() else DESKTOP_SCALE


func show_panel(panel: LDPanel) -> void:
	if current_panel and current_panel != panel:
		current_panel._on_close()
	
	current_panel = panel
	panel.fit_view()
	window.show_view(panel.view, panel.get_title(), panel.window_scale, panel.dim_backdrop)
	panel._on_open()
	panel_changed.emit(panel)


func hide_panel() -> void:
	window.close()


func toggle_panel(panel: LDPanel) -> void:
	if current_panel == panel and window.is_open():
		hide_panel()
	else:
		show_panel(panel)


func is_panel_open() -> bool:
	return window.is_open()


func _on_window_closed() -> void:
	var panel: LDPanel = current_panel
	current_panel = null
	if panel:
		panel._on_close()
	panel_changed.emit(null)


func _rescale() -> void:
	var ui_scale: float = get_ui_scale()
	var view: Vector2 = get_viewport().get_visible_rect().size
	hud.scale = Vector2.ONE * ui_scale
	hud.offset_right = view.x * (1.0 / ui_scale - 1.0)
	hud.offset_bottom = view.y * (1.0 / ui_scale - 1.0)
