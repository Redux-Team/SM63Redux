class_name LDComponent
extends Node


func _on_ready() -> void:
	pass


func _ready() -> void:
	_on_ready()


func _on_input(_event: InputEvent) -> void:
	pass


func set_input_priority() -> void:
	LD.get_input_handler().set_input_priority(self)


func remove_input_priority() -> void:
	LD.get_input_handler().remove_input_priority(self)


func has_input_priority() -> bool:
	return LD.get_input_handler().has_input_priority(self)
