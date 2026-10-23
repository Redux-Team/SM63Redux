@abstract class_name LDPanel
extends LDComponent

@export var view: Control
@export var title: String
@export var toggle_button: BaseButton
@export var action: StringName
@export var window_scale: Vector2 = Vector2.ONE
@export var dim_backdrop: bool = true
@export var screen_margin: Vector2 = Vector2(300, 100)
@export var shrink_vertically: bool = false
@export var max_size: Vector2 = Vector2.INF

var _base_size: Vector2


func _enter_tree() -> void:
	get_viewport().size_changed.connect(fit_view)
	if is_node_ready():
		fit_view()


func _exit_tree() -> void:
	get_viewport().size_changed.disconnect(fit_view)


func _unhandled_input(event: InputEvent) -> void:
	if not action.is_empty() and editor.is_shortcut(event, action):
		toggle()
		get_viewport().set_input_as_handled()


func _setup() -> void:
	view.visible = false
	_base_size = view.custom_minimum_size
	LD.bind_button(toggle_button, toggle)
	editor.interface_handler.panel_changed.connect(
			func(panel: LDPanel) -> void:
				LD.set_active(toggle_button, panel == self)
	)


func open() -> void:
	editor.interface_handler.show_panel(self)


func close() -> void:
	if is_open():
		editor.interface_handler.hide_panel()


func toggle() -> void:
	editor.interface_handler.toggle_panel(self)


func is_open() -> bool:
	return editor.interface_handler.current_panel == self


func fit_view() -> void:
	var fitted: Vector2 = \
			(view.get_viewport_rect().size - screen_margin).min(max_size).max(_base_size)
	if shrink_vertically:
		fitted.y = _base_size.y
	view.custom_minimum_size = fitted


func refit() -> void:
	await get_tree().process_frame
	if is_open():
		editor.interface_handler.window.fit()


func get_title() -> String:
	return title


func _on_open() -> void:
	pass


func _on_close() -> void:
	pass
