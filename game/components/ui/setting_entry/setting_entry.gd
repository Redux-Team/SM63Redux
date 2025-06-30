@tool
class_name SettingEntry
extends Control

enum SettingType {
	BOOLEAN,
	DROPDOWN,
}

@export var setting_group: StringName = &"General"
@export var setting_name: StringName = &""
@export var widget: SettingType

@export_group("Dropdown")
@export var dropdown_contents: Array[String]

@export_group("Internal")
@export var boolean_widget_container: AspectRatioContainer
@export var setting_label: Label
@export var interaction: Button


func _ready() -> void:
	interaction.pressed.connect(_on_interaction)
	
	if widget == SettingType.BOOLEAN:
		boolean_widget_container.show()
	
	setting_label.text = setting_name


func _on_interaction() -> void:
	match widget:
		SettingType.BOOLEAN:
			boolean_widget_container._check()




func _on_interaction_mouse_entered() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.YELLOW)


func _on_interaction_mouse_exited() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.WHITE)


func _on_interaction_button_up() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.YELLOW)


func _on_interaction_button_down() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.AQUA)


func _on_interaction_focus_entered() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.YELLOW)


func _on_interaction_focus_exited() -> void:
	setting_label.add_theme_color_override(&"font_color", Color.WHITE)
