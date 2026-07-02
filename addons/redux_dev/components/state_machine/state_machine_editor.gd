@tool
class_name EditorStateMachineEditor
extends Control

@export var graph_edit: GraphEdit
@export var state_machine_graph_edit: EditorStateMachineGraphEdit
@export var current_node_button: Button

var _current_sm: StateMachine = null


func load_state_machine(state_machine: StateMachine) -> void:
	_current_sm = state_machine
	if state_machine_graph_edit:
		state_machine_graph_edit._reload()
	_update_header()


func _update_header() -> void:
	if not current_node_button:
		return
	var label: String = "<empty>"
	if _current_sm:
		var node: Node = _current_sm.get_node_or_null(_current_sm.root_node)
		if node:
			label = String(node.name)
	current_node_button.text = label


func _is_plugin_instance() -> bool:
	return get_parent() is EditorDock
