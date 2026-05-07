@tool
class_name EditorStateMachineEditor
extends Control

static var _instance: EditorStateMachineEditor

const TRANSITION_SCRIPT_TEXT: String = """%s
@tool
extends StateTransition

func _should_transition() -> bool:
	return true


func _on_before_transition() -> void:
	pass


func _on_after_transition() -> void:
	pass
"""

@export var graph_edit: GraphEdit
@export var state_machine_graph_edit: EditorStateMachineGraphEdit
@export var save_script_dialog: FileDialog

var _current_sm: StateMachine = null


func _ready() -> void:
	_instance = self


static func prompt_transition_script(transition: StateTransition) -> void:
	if _instance:
		_instance._open_or_create_transition_script(transition)


static func _make_transition_script(from_name: String, to_name: String) -> GDScript:
	var template: String = FileAccess.get_file_as_string("res://addons/redux_dev/templates/state_transition.txt")
	var s: GDScript = GDScript.new()
	s.source_code = template % [from_name, to_name]
	s.resource_local_to_scene = true
	return s


static func _make_state_script(state_name: String) -> GDScript:
	var s: GDScript = GDScript.new()
	s.source_code = "extends State\n\n\nfunc _should_transition() -> bool:\n\treturn true\n"
	s.resource_local_to_scene = true
	return s


func _open_or_create_transition_script(transition: StateTransition) -> void:
	var s: Script = transition.get_script() as Script
	if s and s != StateTransition:
		EditorInterface.edit_script(s)
		EditorInterface.set_main_screen_editor("Script")
		return
	
	var from_name: String = transition.__from_uuid
	var to_name: String = transition.__to_uuid
	if _current_sm:
		var from_state: State = _current_sm.__states.get(transition.__from_uuid) as State
		var to_state: State = _current_sm.__states.get(transition.__to_uuid) as State
		if from_state:
			from_name = from_state.name
		else:
			var from_node: EditorStateMachineStateNode = state_machine_graph_edit._find_node_by_uuid(transition.__from_node_uuid)
			if from_node:
				from_name = from_node.title
		if to_state:
			to_name = to_state.name
		else:
			var to_node: EditorStateMachineStateNode = state_machine_graph_edit._find_node_by_uuid(transition.__to_node_uuid)
			if to_node:
				to_name = to_node.title
	
	var from_uuid: String = transition.__from_uuid
	var to_uuid: String = transition.__to_uuid
	var from_node_uuid: StringName = transition.__from_node_uuid
	var to_node_uuid: StringName = transition.__to_node_uuid
	
	var new_script: GDScript = _make_transition_script(from_name, to_name)
	transition.set_script(new_script)
	transition.__from_uuid = from_uuid
	transition.__to_uuid = to_uuid
	transition.__from_node_uuid = from_node_uuid
	transition.__to_node_uuid = to_node_uuid
	
	EditorInterface.edit_script(new_script)
	EditorInterface.set_main_screen_editor("Script")


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
	
	for uuid: String in _current_sm.__aliases:
		state_machine_graph_edit._spawn_alias_node(uuid)
	
	for uuid: String in _current_sm.__annotations:
		state_machine_graph_edit._spawn_annotation_node(uuid)
	
	state_machine_graph_edit._restore_connections.call_deferred()


func _open_or_create_state_script(uuid: String) -> void:
	var state: State = _current_sm.__states.get(uuid)
	if not state:
		return
	var s: Script = state.get_script() as Script
	if s and s != State:
		EditorInterface.edit_script(s)
		EditorInterface.set_main_screen_editor("Script")
		return
	
	EditorInterface.popup_quick_open(func(selected: String) -> void:
		var loaded: Script = load(selected)
		if not loaded:
			return
		var editor_name: StringName = state.__editor_name
		var editor_position: Vector2 = state.__editor_position
		var editor_uuid: StringName = state.__editor_uuid
		var editor_superstate_uuid: StringName = state.__editor_superstate_uuid
		var editor_entry_uuid: StringName = state.__editor_entry_uuid
		var editor_superstate_wire_uuid: StringName = state.__editor_superstate_wire_uuid
		state.set_script(loaded)
		state.__editor_name = editor_name
		state.__editor_position = editor_position
		state.__editor_uuid = editor_uuid
		state.__editor_superstate_uuid = editor_superstate_uuid
		state.__editor_entry_uuid = editor_entry_uuid
		state.__editor_superstate_wire_uuid = editor_superstate_wire_uuid
		EditorInterface.edit_script(loaded)
		EditorInterface.set_main_screen_editor("Script")
		var node: EditorStateMachineStateNode = state_machine_graph_edit._find_node_by_uuid(uuid)
		if node:
			node._update_script_button()
	, PackedStringArray(["Script"]))


func _on_save_script_dialog_file_selected(path: String) -> void:
	var uuid: String = save_script_dialog.get_meta("target_uuid", "")
	var transition: StateTransition = save_script_dialog.get_meta("target_transition", null)
	
	if not uuid.is_empty():
		var state: State = _current_sm.__states.get(uuid)
		if not state:
			return
		var editor_name: StringName = state.__editor_name
		var editor_position: Vector2 = state.__editor_position
		var editor_uuid: StringName = state.__editor_uuid
		var editor_superstate_uuid: StringName = state.__editor_superstate_uuid
		var editor_entry_uuid: StringName = state.__editor_entry_uuid
		var editor_superstate_wire_uuid: StringName = state.__editor_superstate_wire_uuid
		var loaded: Script = load(path)
		state.set_script(loaded)
		state.__editor_name = editor_name
		state.__editor_position = editor_position
		state.__editor_uuid = editor_uuid
		state.__editor_superstate_uuid = editor_superstate_uuid
		state.__editor_entry_uuid = editor_entry_uuid
		state.__editor_superstate_wire_uuid = editor_superstate_wire_uuid
		EditorInterface.edit_script(loaded)
		EditorInterface.set_main_screen_editor("Script")
		var node: EditorStateMachineStateNode = state_machine_graph_edit._find_node_by_uuid(uuid)
		if node:
			node._update_script_button()
	elif transition:
		var s: GDScript = GDScript.new()
		s.source_code = "extends StateTransition\n\n\nfunc _should_transition() -> bool:\n\treturn true\n\n\nfunc _on_before_transition() -> void:\n\tpass\n\n\nfunc _on_after_transition() -> void:\n\tpass\n"
		s.resource_local_to_scene = true
		transition.set_script(s)
		EditorInterface.edit_script(s)
		EditorInterface.set_main_screen_editor("Script")
	
	save_script_dialog.set_meta("target_transition", null)


func _is_plugin_instance() -> bool:
	return get_parent() is EditorDock
