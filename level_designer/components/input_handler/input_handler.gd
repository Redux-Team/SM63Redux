class_name LDInputHandler
extends Node


var _input_priority_stack: Array[LDComponent]


func get_node_with_input_priority() -> Node:
	if _input_priority_stack.is_empty():
		return null
	return _input_priority_stack.front()


func set_input_priority(ref: LDComponent) -> void:
	remove_input_priority(ref)
	_input_priority_stack.push_front(ref)


func has_input_priority(ref: LDComponent) -> bool:
	return not _input_priority_stack.is_empty() and ref == _input_priority_stack.front()


func remove_input_priority(ref: LDComponent) -> void:
	if ref in _input_priority_stack:
		_input_priority_stack.remove_at(_input_priority_stack.find(ref))


func dispatch(event: InputEvent) -> void:
	if _input_priority_stack.is_empty():
		return
	_input_priority_stack.front()._on_input(event)
