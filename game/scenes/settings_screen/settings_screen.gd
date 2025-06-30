@tool
extends Control

signal exit_request

@export var settings_container: Control


func _on_cycle(index: int, last: int) -> void:
	settings_container.get_child(last).hide()
	settings_container.get_child(index).show()
