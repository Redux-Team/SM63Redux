@tool
extends Control

signal exit_request

@export var settings_container: Control
@export var controls_vbox: Control
@export var setting_cycle_button: Button
@export var touch_subviewport: SubViewport


func _on_cycle(index: int, last: int) -> void:
	settings_container.get_child(last).hide()
	settings_container.get_child(index).show()


func _on_visibility_changed() -> void:
	if visible and not Engine.is_editor_hint():
		setting_cycle_button.grab_focus()


func _on_back_button_pressed() -> void:
	exit_request.emit()
