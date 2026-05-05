@tool
class_name EditorStateMachineEditor
extends Control

@export var graph_edit: GraphEdit
@export var state_machine_graph_edit: EditorStateMachineGraphEdit

var _current_sm: StateMachine = null


func load_state_machine(state_machine: StateMachine) -> void:
	_current_sm = state_machine
	_refresh()


func _refresh() -> void:
	state_machine_graph_edit.clear_connections()
	
	for child: Node in graph_edit.get_children():
		if child is GraphElement:
			child.free()
	
	state_machine_graph_edit.scroll_offset = _current_sm.__last__editor_position
	state_machine_graph_edit.zoom = _current_sm.__last_editor_zoom
	
	for uuid: String in _current_sm.__states:
		state_machine_graph_edit._spawn_state_node(uuid)
	
	for uuid: String in _current_sm.__annotations:
		state_machine_graph_edit._spawn_annotation_node(uuid)
	
	state_machine_graph_edit._restore_connections()


func _is_plugin_instance() -> bool:
	return get_parent() is EditorDock
