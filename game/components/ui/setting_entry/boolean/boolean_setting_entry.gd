@tool
class_name BooleanSettingEntry
extends Control

signal value_changed(value: bool)


@export var setting_group: StringName = "General"
@export var setting_name: StringName = ""
@export var value: bool = true:
	set(v):
		_value = v
		boolean_widget.set_toggled(v, false)
	get():
		return _value

var _value: bool = true

@export_group("Internal")
@export var boolean_widget: BooleanWidget
@export var setting_label: Label
@export var interaction: Button


func _ready() -> void:
	interaction.pressed.connect(_on_interaction)
	boolean_widget.set_toggled(_value, false)
	boolean_widget.show()
	setting_label.text = setting_name


func get_value() -> Variant:
	return boolean_widget._get_checkbox_value()


func _on_interaction() -> void:
	if not boolean_widget.hovering:
		boolean_widget.set_toggled(not boolean_widget.toggled)
	
	value_changed.emit(boolean_widget.toggled)


func _on_interaction_mouse_entered() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.YELLOW)


func _on_interaction_mouse_exited() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.WHITE)


func _on_interaction_button_down() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.AQUA)


func _on_interaction_button_up() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.YELLOW)


func _on_interaction_focus_entered() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.YELLOW)


func _on_interaction_focus_exited() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.WHITE)
