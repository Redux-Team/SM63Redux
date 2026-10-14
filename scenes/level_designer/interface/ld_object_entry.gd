class_name LDObjectEntry
extends Button

@export var preview: TextureRect

var entry: ObjectRegistry.Entry


func setup(object_entry: ObjectRegistry.Entry) -> void:
	entry = object_entry
	preview.texture = entry.get_icon()
