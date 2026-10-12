@tool
class_name SettingsScreen
extends UICanvasGroup

signal closed

@export var category_container: VBoxContainer
@export var category_label: Label
@export var widget_container: VBoxContainer

var _category_group: ButtonGroup = ButtonGroup.new()
var _category: SettingsCategory
var _snapshot: Dictionary[SettingsType, String] = {}
var _snapshot_preset: String = ""


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	for category: SettingsCategory in _categories():
		if category.visible_settings().is_empty():
			continue
		var button: Button = Button.new()
		button.text = category.name.to_lower()
		button.toggle_mode = true
		button.button_group = _category_group
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		GDSS.add_class(button, "SidebarButton")
		button.toggled.connect(_on_category_toggled.bind(category))
		category_container.add_child(button)
	if category_container.get_child_count() > 0:
		(category_container.get_child(0) as Button).button_pressed = true


func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_cancel_button_pressed()


func open() -> void:
	_snapshot.clear()
	for category: SettingsCategory in _categories():
		for setting: SettingsType in category.settings():
			_snapshot.set(setting, setting._serialize())
	_snapshot_preset = Settings.active_input_preset
	if _category != null:
		_show_category(_category)


func _categories() -> Array[SettingsCategory]:
	var categories: Array[SettingsCategory] = []
	for child: Node in Settings.get_children():
		if child is SettingsCategory:
			categories.append(child)
	return categories


func _show_category(category: SettingsCategory) -> void:
	_category = category
	category_label.text = category.name
	for child: Node in widget_container.get_children():
		widget_container.remove_child(child)
		child.queue_free()
	for setting: SettingsType in category.visible_settings():
		var widget: PropertyWidget = PropertyWidget.create(setting.binding())
		if widget != null:
			widget_container.add_child(widget)


func _on_category_toggled(toggled_on: bool, category: SettingsCategory) -> void:
	if toggled_on:
		_show_category(category)


func _on_restore_defaults_pressed() -> void:
	Settings.restore_defaults()
	_show_category(_category)


func _on_cancel_button_pressed() -> void:
	for setting: SettingsType in _snapshot:
		if setting._serialize() != _snapshot.get(setting):
			setting._deserialize(_snapshot.get(setting))
	Settings.active_input_preset = _snapshot_preset
	Settings.save()
	closed.emit()


func _on_apply_button_pressed() -> void:
	Settings.save()
	closed.emit()
