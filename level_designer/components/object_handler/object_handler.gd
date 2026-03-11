class_name LDObjectHandler
extends Node

signal selected_object_changed(new: GameObject)

var _selected_object: GameObject


func get_selected_object() -> GameObject:
	return _selected_object


func select_object(object: GameObject) -> void:
	_selected_object = object
	selected_object_changed.emit(object)
