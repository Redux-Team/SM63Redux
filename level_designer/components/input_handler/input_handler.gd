class_name LDInputHandler
extends Node

var _input_priority_stack: Array[LDComponent]


func _input(event: InputEvent) -> void:
	if _input_priority_stack.is_empty():
		return
	
	_input_priority_stack.front()._on_input(event)


func get_node_with_input_priority() -> Node:
	if _input_priority_stack.is_empty():
		return null
	return _input_priority_stack.front()


func set_input_priority(ref: Node) -> void:
	remove_input_priority(ref)
	_input_priority_stack.push_front(ref)


func has_input_priority(ref: Node) -> bool:
	return not _input_priority_stack.is_empty() and ref == _input_priority_stack.front()


func remove_input_priority(ref: Node) -> void:
	if ref in _input_priority_stack:
		_input_priority_stack.remove_at(_input_priority_stack.find(ref))
