@abstract class_name LDPanel
extends LDComponent

@export var view: Control
@export var title: String
@export var toggle_button: BaseButton
@export var action: StringName
@export var window_scale: Vector2 = Vector2.ONE
@export var dim_backdrop: bool = true
@export var screen_margin: Vector2 = Vector2(300, 100)

var _base_size: Vector2


func _setup() -> void:
	view.visible = false
	_base_size = view.custom_minimum_size
	view.get_viewport().size_changed.connect(fit_view)
	LD.bind_button(toggle_button, toggle)
	editor.interface_handler.panel_changed.connect(func(panel: LDPanel) -> void: LD.set_active(toggle_button, panel == self))


func _unhandled_input(event: InputEvent) -> void:
	if not action.is_empty() and editor.is_shortcut(event, action):
		toggle()
		get_viewport().set_input_as_handled()


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
	view.custom_minimum_size = (view.get_viewport_rect().size - screen_margin).max(_base_size)


func get_title() -> String:
	return title


func _on_open() -> void:
	pass


func _on_close() -> void:
	pass
