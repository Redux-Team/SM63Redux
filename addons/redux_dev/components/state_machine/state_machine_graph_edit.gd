@tool
class_name EditorStateMachineGraphEdit
extends GraphEdit

const SCENE_STATE_NODE = preload("uid://lw2tqa550ufn")
const SCENE_ANNOTATION = preload("uid://cxlnpbgvix7ms")
const SCENE_ENTRY_NODE = preload("uid://cc2qqqr86hdcx")
const PORT_TRANSITION: int = 0
const PORT_SUPERSTATE: int = 1

enum MenuItem {
	NEW_STATE,
	NEW_ANNOTATION,
	NEW_ALIAS,
}

@export var add_node_menu: PopupMenu
@export var add_state_dialog: AcceptDialog
@export var add_annotation_dialog: AcceptDialog
@export var state_machine_editor: EditorStateMachineEditor
@export var new_state_name_input: LineEdit
@export var new_annotation_input: LineEdit
@export var connection_overlay: Control

var _popup_pos: Vector2
var _node_to_state: Dictionary[StringName, State] = {}
var _state_to_node: Dictionary[State, StringName] = {}
var _alias_ids: Dictionary[StringName, String] = {}
var _routes: Dictionary = {}
var _selected_transition: StateTransition
var _selected_wire: Array[StringName] = []
var _detach_from: State
var _detach_to: State
var _detach_superstate_child: State
var _detach_entry: bool = false
var _wire_drag_active: bool = false
var _refresh_queued: bool = false
var _save_queued: bool = false


func _init() -> void:
	delete_nodes_request.connect(_on_delete_nodes_request)


func _ready() -> void:
	if not state_machine_editor or not state_machine_editor._is_plugin_instance():
		return
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	connection_drag_started.connect(_on_connection_drag_started)
	connection_drag_ended.connect(_on_connection_drag_ended)
	scroll_offset_changed.connect(_on_scroll_offset_changed)
	connection_overlay.draw.connect(_on_overlay_draw)


func _sm() -> StateMachine:
	if not state_machine_editor:
		return null
	return state_machine_editor._current_sm


func _scene_root() -> Node:
	var sm: StateMachine = _sm()
	if not sm:
		return null
	return sm.owner if sm.owner else sm


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_RIGHT and mb.pressed:
			if _detach_from or _detach_superstate_child or _detach_entry:
				_end_detach()
				_refresh()
				return
			if _wire_drag_active:
				return
			_popup_pos = (mb.position + scroll_offset) / zoom
			_rebuild_add_menu()
			add_node_menu.position = Vector2i(mb.global_position)
			add_node_menu.popup()
		elif mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
			_try_inspect_connection(mb.position)


func _rebuild_add_menu() -> void:
	add_node_menu.clear()
	add_node_menu.add_item("+ State", MenuItem.NEW_STATE)
	add_node_menu.add_item("+ Annotation", MenuItem.NEW_ANNOTATION)
	if _single_selected_state_node():
		add_node_menu.add_item("+ Alias", MenuItem.NEW_ALIAS)


func _on_scroll_offset_changed(_offset: Vector2) -> void:
	connection_overlay.queue_redraw()
	_queue_save_layout()


func _on_add_node_menu_id_pressed(id: int) -> void:
	match id:
		MenuItem.NEW_STATE:
			add_state_dialog.popup_centered()
		MenuItem.NEW_ANNOTATION:
			add_annotation_dialog.popup_centered()
		MenuItem.NEW_ALIAS:
			_add_alias(_single_selected_state_node())


func _on_add_state_dialog_confirmed() -> void:
	var label: String = new_state_name_input.text.strip_edges()
	new_state_name_input.text = ""
	if not _sm():
		return
	var base: String = label.to_pascal_case() if not label.is_empty() else "State"
	_add_state(_selected_state_parent(), base, _popup_pos)


func _on_add_annotation_dialog_confirmed() -> void:
	var text: String = new_annotation_input.text.strip_edges()
	new_annotation_input.text = ""
	if text.is_empty() or not _sm():
		return
	_spawn_annotation(text, _popup_pos)
	_queue_save_layout()


func _single_selected_state_node() -> EditorStateMachineStateNode:
	var selected: EditorStateMachineStateNode
	for child: Node in get_children():
		if child is EditorStateMachineStateNode:
			var node: EditorStateMachineStateNode = child
			if node.selected and is_instance_valid(node.state):
				if selected:
					return null
				selected = node
	return selected


func _selected_state_parent() -> Node:
	var sm: StateMachine = _sm()
	var selected: State
	for child: Node in get_children():
		if child is EditorStateMachineStateNode:
			var node: EditorStateMachineStateNode = child
			if node.selected and is_instance_valid(node.state):
				if selected:
					return sm
				selected = node.state
	return selected if selected else sm


func _add_state(parent: Node, base_name: String, pos: Vector2) -> void:
	var sm: StateMachine = _sm()
	if not sm or not is_instance_valid(parent):
		return
	var state_name: String = _unique_child_name(parent, base_name)
	var new_state: State = State.new()
	new_state.name = state_name
	var relpath: String = _relpath_for_new(parent, state_name)
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo.create_action("Add State", UndoRedo.MERGE_DISABLE, sm)
	undo.add_do_method(parent, &"add_child", new_state)
	undo.add_do_property(new_state, &"owner", _scene_root())
	undo.add_do_method(self, &"_store_state_position", relpath, pos)
	undo.add_do_reference(new_state)
	undo.add_do_method(self, &"_refresh")
	undo.add_undo_method(parent, &"remove_child", new_state)
	undo.add_undo_method(self, &"_refresh")
	undo.commit_action()


func _add_alias(source: EditorStateMachineStateNode) -> void:
	if not source or not _sm():
		return
	_spawn_alias_node(_new_alias_id(), source.state, _popup_pos)
	_save_layout()


func _new_alias_id() -> String:
	var i: int = 1
	while _alias_ids.values().has("a%d" % i):
		i += 1
	return "a%d" % i


func _commit_transitions(state: State, action_name: String, new_transitions: Array[StateTransition]) -> void:
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo.create_action(action_name, UndoRedo.MERGE_DISABLE, _sm())
	undo.add_do_property(state, &"transitions", new_transitions)
	undo.add_undo_property(state, &"transitions", state.transitions)
	undo.add_do_method(self, &"_refresh")
	undo.add_undo_method(self, &"_refresh")
	undo.commit_action()


func _add_transition(from_state: State, to_state: State, from_node: StringName, to_node: StringName) -> void:
	var sm: StateMachine = _sm()
	if not sm or _find_transition(from_state, to_state):
		return
	var t: StateTransition = StateTransition.new()
	t.resource_name = _unique_transition_name(from_state, "To" + String(to_state.name))
	t.target = sm.get_path_to(to_state)
	var after: Array[StateTransition] = from_state.transitions.duplicate()
	after.append(t)
	_commit_transitions(from_state, "Add Transition", after)
	_selected_transition = t
	_selected_wire = [from_node, to_node]
	EditorInterface.inspect_object(t)


func _remove_transition(from_state: State, to_state: State) -> void:
	var sm: StateMachine = _sm()
	var after: Array[StateTransition] = []
	for t: StateTransition in from_state.transitions:
		if not t or sm.get_node_or_null(t.target) != to_state:
			after.append(t)
	if after.size() == from_state.transitions.size():
		return
	_commit_transitions(from_state, "Remove Transition", after)


func _retarget_transitions(from_state: State, old_to: State, new_to: State) -> void:
	var sm: StateMachine = _sm()
	var path: NodePath = sm.get_path_to(new_to)
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo.create_action("Move Transition", UndoRedo.MERGE_DISABLE, sm)
	for t: StateTransition in from_state.transitions:
		if not t or sm.get_node_or_null(t.target) != old_to:
			continue
		undo.add_do_property(t, &"target", path)
		undo.add_undo_property(t, &"target", t.target)
		if t.resource_name == "To" + String(old_to.name):
			undo.add_do_property(t, &"resource_name", "To" + String(new_to.name))
			undo.add_undo_property(t, &"resource_name", t.resource_name)
	undo.add_do_method(self, &"_refresh")
	undo.add_undo_method(self, &"_refresh")
	undo.commit_action()


func _set_superstate(parent_state: State, child_state: State) -> void:
	_reparent_state(parent_state, child_state)


func _detach_superstate(child_state: State) -> void:
	_reparent_state(_sm(), child_state)


func _reparent_state(new_parent: Node, child_state: State) -> void:
	var sm: StateMachine = _sm()
	if not sm or not is_instance_valid(new_parent) or not is_instance_valid(child_state):
		return
	if new_parent == child_state or _is_descendant(new_parent, child_state):
		return
	if child_state.get_parent() == new_parent:
		return
	var old_parent: Node = child_state.get_parent()
	var old_idx: int = child_state.get_index()
	var old_name: String = String(child_state.name)
	var new_name: String = old_name
	if new_parent.has_node(NodePath(old_name)):
		new_name = _unique_child_name(new_parent, old_name)
	var old_rel: String = String(sm.get_path_to(child_state))
	var new_rel: String = _relpath_for_new(new_parent, new_name)
	var targets: Dictionary = _capture_targets()
	var initial: State = sm.initial_state
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo.create_action("Set Superstate", UndoRedo.MERGE_DISABLE, sm)
	undo.add_do_method(old_parent, &"remove_child", child_state)
	if new_name != old_name:
		undo.add_do_property(child_state, &"name", new_name)
	undo.add_do_method(new_parent, &"add_child", child_state)
	undo.add_do_property(child_state, &"owner", _scene_root())
	undo.add_do_method(self, &"_reown_subtree", child_state)
	undo.add_do_method(self, &"_restore_targets", targets)
	undo.add_do_method(self, &"_rekey_sidecar_paths", old_rel, new_rel)
	if initial:
		undo.add_do_property(sm, &"initial_state", initial)
	undo.add_do_method(self, &"_refresh")
	undo.add_undo_method(new_parent, &"remove_child", child_state)
	if new_name != old_name:
		undo.add_undo_property(child_state, &"name", old_name)
	undo.add_undo_method(old_parent, &"add_child", child_state)
	undo.add_undo_method(old_parent, &"move_child", child_state, old_idx)
	undo.add_undo_property(child_state, &"owner", _scene_root())
	undo.add_undo_method(self, &"_reown_subtree", child_state)
	undo.add_undo_method(self, &"_restore_targets", targets)
	undo.add_undo_method(self, &"_rekey_sidecar_paths", new_rel, old_rel)
	if initial:
		undo.add_undo_property(sm, &"initial_state", initial)
	undo.add_undo_method(self, &"_refresh")
	undo.commit_action()


func _set_initial_state(target: State) -> void:
	var sm: StateMachine = _sm()
	if not sm:
		return
	var old: State = sm.initial_state
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo.create_action("Set Initial State", UndoRedo.MERGE_DISABLE, sm)
	undo.add_do_property(sm, &"initial_state", target)
	undo.add_do_method(self, &"_refresh")
	undo.add_undo_property(sm, &"initial_state", old)
	undo.add_undo_method(self, &"_refresh")
	undo.commit_action()


func _delete_states(states: Array[State]) -> void:
	var sm: StateMachine = _sm()
	if not sm:
		return
	var undo: EditorUndoRedoManager = EditorInterface.get_editor_undo_redo()
	undo.create_action("Delete State", UndoRedo.MERGE_DISABLE, sm)
	var deleted: Dictionary = {}
	for s: State in states:
		deleted[s] = true
		for d: State in _descendant_states(s):
			deleted[d] = true
	var clears_initial: bool = false
	for s: State in states:
		if _is_descendant(sm.initial_state, s):
			clears_initial = true
			break
	if clears_initial:
		undo.add_do_property(sm, &"initial_state", null)
	var all_states: Array[State] = []
	_collect_states(sm, all_states)
	for s: State in all_states:
		if deleted.has(s):
			continue
		var kept: Array[StateTransition] = []
		for t: StateTransition in s.transitions:
			var target: Node = sm.get_node_or_null(t.target) if t else null
			if not (target and deleted.has(target)):
				kept.append(t)
		if kept.size() != s.transitions.size():
			undo.add_do_property(s, &"transitions", kept)
			undo.add_undo_property(s, &"transitions", s.transitions)
	for s: State in states:
		if _in_deleted_ancestry(s.get_parent(), deleted):
			continue
		_add_remove_node_ops(undo, s)
	if clears_initial:
		undo.add_undo_property(sm, &"initial_state", sm.initial_state)
	undo.add_do_method(self, &"_refresh")
	undo.add_undo_method(self, &"_refresh")
	undo.commit_action()


func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	var states_to_delete: Array[State] = []
	var layout_dirty: bool = false
	for node_name: StringName in node_names:
		var node: Node = get_node_or_null(NodePath(node_name))
		if node is EditorStateMachineStateNode:
			var state_node: EditorStateMachineStateNode = node
			if state_node.is_alias:
				_remove_alias_node(state_node)
				layout_dirty = true
			elif is_instance_valid(state_node.state):
				states_to_delete.append(state_node.state)
		elif node is EditorStateMachineAnnotation:
			node.free()
			layout_dirty = true
	if layout_dirty:
		_save_layout()
		_refresh()
	if not states_to_delete.is_empty():
		_delete_states(states_to_delete)


func _remove_alias_node(node: EditorStateMachineStateNode) -> void:
	var alias_id: String = _alias_ids.get(node.name, "")
	_alias_ids.erase(node.name)
	_node_to_state.erase(node.name)
	for key: Variant in _routes.keys():
		var route: Dictionary = _routes.get(key)
		if String(route.get("from", "")) == alias_id:
			route.erase("from")
		if String(route.get("to", "")) == alias_id:
			route.erase("to")
		if route.is_empty():
			_routes.erase(key)
	node.free()


func _on_connection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_element: Node = get_node_or_null(NodePath(from_node))
	var to_state: State = _node_to_state.get(to_node)
	if from_element is EditorStateMachineEntryExitNode and to_state:
		var was_entry_detach: bool = _detach_entry
		_end_detach()
		if was_entry_detach and to_state == _sm().initial_state:
			_refresh()
			return
		_set_initial_state(to_state)
		return
	var from_state: State = _node_to_state.get(from_node)
	if not from_state or not to_state:
		return
	if from_port == PORT_TRANSITION and to_port == PORT_TRANSITION:
		if _detach_from and from_state == _detach_from:
			_finish_detach_drop(from_state, to_state, from_node, to_node)
			return
		_end_detach()
		_update_route(from_state, to_state, from_node, to_node)
		if _find_transition(from_state, to_state):
			_refresh()
		else:
			_add_transition(from_state, to_state, from_node, to_node)
	elif from_port == PORT_SUPERSTATE and to_port == PORT_SUPERSTATE:
		var pending_child: State = _detach_superstate_child
		_end_detach()
		if from_state == to_state or pending_child == to_state:
			_refresh()
			return
		if pending_child:
			_detach_superstate(pending_child)
		_set_superstate(from_state, to_state)


func _on_disconnection_request(from_node: StringName, from_port: int, to_node: StringName, to_port: int) -> void:
	var from_element: Node = get_node_or_null(NodePath(from_node))
	if from_element is EditorStateMachineEntryExitNode:
		_detach_entry = true
		disconnect_node(from_node, from_port, to_node, to_port)
		return
	var from_state: State = _node_to_state.get(from_node)
	var to_state: State = _node_to_state.get(to_node)
	if not from_state or not to_state:
		return
	if from_port == PORT_TRANSITION and to_port == PORT_TRANSITION:
		_detach_from = from_state
		_detach_to = to_state
		disconnect_node(from_node, PORT_TRANSITION, to_node, PORT_TRANSITION)
		connection_overlay.queue_redraw()
	elif from_port == PORT_SUPERSTATE and to_port == PORT_SUPERSTATE:
		_detach_superstate_child = to_state
		disconnect_node(from_node, PORT_SUPERSTATE, to_node, PORT_SUPERSTATE)


func _on_connection_drag_started(_from_node: StringName, _from_port: int, _is_output: bool) -> void:
	_wire_drag_active = true


func _on_connection_drag_ended() -> void:
	_wire_drag_active = false
	if _detach_entry:
		_end_detach()
		_set_initial_state(null)
		return
	if _detach_superstate_child:
		var child: State = _detach_superstate_child
		_end_detach()
		_detach_superstate(child)
		return
	if not _detach_from:
		return
	var from_state: State = _detach_from
	var to_state: State = _detach_to
	_end_detach()
	_routes.erase(_route_key(from_state, to_state))
	_queue_save_layout()
	_remove_transition(from_state, to_state)


func _finish_detach_drop(from_state: State, to_state: State, from_node: StringName, to_node: StringName) -> void:
	var old_to: State = _detach_to
	_end_detach()
	if to_state == old_to:
		_update_route(from_state, to_state, from_node, to_node)
		_refresh()
		return
	_selected_transition = null
	_selected_wire.clear()
	_routes.erase(_route_key(from_state, old_to))
	_update_route(from_state, to_state, from_node, to_node)
	if _find_transition(from_state, to_state):
		_remove_transition(from_state, old_to)
	else:
		_retarget_transitions(from_state, old_to, to_state)


func _end_detach() -> void:
	_detach_from = null
	_detach_to = null
	_detach_superstate_child = null
	_detach_entry = false


func _route_key(from_state: State, to_state: State) -> String:
	var sm: StateMachine = _sm()
	return "%s -> %s" % [sm.get_path_to(from_state), sm.get_path_to(to_state)]


func _update_route(from_state: State, to_state: State, from_node: StringName, to_node: StringName) -> void:
	var key: String = _route_key(from_state, to_state)
	var route: Dictionary = {}
	if _alias_ids.has(from_node):
		route["from"] = _alias_ids.get(from_node)
	if _alias_ids.has(to_node):
		route["to"] = _alias_ids.get(to_node)
	if route.is_empty():
		_routes.erase(key)
	else:
		_routes[key] = route
	_queue_save_layout()


func _routed_endpoint(state: State, route: Dictionary, side: String) -> StringName:
	var alias_id: String = String(route.get(side, ""))
	if not alias_id.is_empty():
		var node_name: StringName = StringName("alias_" + alias_id)
		if _node_to_state.get(node_name) == state:
			return node_name
	return _state_to_node.get(state)


func _add_remove_node_ops(undo: EditorUndoRedoManager, node: Node) -> void:
	var parent: Node = node.get_parent()
	var idx: int = node.get_index()
	var node_owner: Node = node.owner
	undo.add_do_method(parent, &"remove_child", node)
	undo.add_undo_method(parent, &"add_child", node)
	undo.add_undo_method(parent, &"move_child", node, idx)
	undo.add_undo_property(node, &"owner", node_owner)
	undo.add_undo_method(self, &"_reown_subtree", node)
	undo.add_undo_reference(node)


func _capture_targets() -> Dictionary:
	var sm: StateMachine = _sm()
	var result: Dictionary = {}
	var states: Array[State] = []
	_collect_states(sm, states)
	for s: State in states:
		for t: StateTransition in s.transitions:
			if not t:
				continue
			var target: State = sm.get_node_or_null(t.target) as State
			if target:
				result[t] = target
	return result


func _restore_targets(targets: Dictionary) -> void:
	var sm: StateMachine = _sm()
	for t: StateTransition in targets:
		var target: Variant = targets.get(t)
		if is_instance_valid(target):
			t.target = sm.get_path_to(target as Node)


func _rekey_sidecar_paths(old_rel: String, new_rel: String) -> void:
	var sm: StateMachine = _sm()
	if not sm:
		return
	var rekeys: Dictionary = {}
	rekeys[old_rel] = new_rel
	sm._editor_rekey_sidecar(rekeys)


func _reown_subtree(node: Node) -> void:
	var root: Node = _scene_root()
	for child: Node in node.get_children():
		child.owner = root
		_reown_subtree(child)


func _store_state_position(relpath: String, pos: Vector2) -> void:
	var data: Dictionary = _load_sidecar()
	var states: Dictionary = data.get("states", {}) as Dictionary
	states[relpath] = [pos.x, pos.y]
	data["states"] = states
	_save_sidecar(data)


func _find_transition(from_state: State, to_state: State) -> StateTransition:
	var sm: StateMachine = _sm()
	for t: StateTransition in from_state.transitions:
		if t and sm.get_node_or_null(t.target) == to_state:
			return t
	return null


func _unique_transition_name(state: State, base: String) -> String:
	var names: Dictionary = {}
	for t: StateTransition in state.transitions:
		if t:
			names[t.resource_name] = true
	var candidate: String = base
	var i: int = 1
	while names.has(candidate):
		candidate = "%s%d" % [base, i]
		i += 1
	return candidate


func _collect_states(node: Node, out: Array[State]) -> void:
	for child: Node in node.get_children():
		if child is State:
			out.append(child)
			_collect_states(child, out)


func _descendant_states(s: State) -> Array[State]:
	var result: Array[State] = []
	_collect_states(s, result)
	return result


func _in_deleted_ancestry(node: Node, deleted: Dictionary) -> bool:
	var n: Node = node
	while n:
		if deleted.has(n):
			return true
		n = n.get_parent()
	return false


func _is_descendant(node: Node, ancestor: Node) -> bool:
	if not node or not ancestor:
		return false
	var n: Node = node
	while n:
		if n == ancestor:
			return true
		n = n.get_parent()
	return false


func _unique_child_name(parent: Node, base: String) -> String:
	var candidate: String = base
	var i: int = 1
	while parent.has_node(NodePath(candidate)):
		candidate = "%s%d" % [base, i]
		i += 1
	return candidate


func _relpath_for_new(parent: Node, child_name: String) -> String:
	var sm: StateMachine = _sm()
	if parent == sm:
		return child_name
	return String(sm.get_path_to(parent)) + "/" + child_name


func _refresh() -> void:
	if _refresh_queued:
		return
	_refresh_queued = true
	_do_refresh.call_deferred()


func _do_refresh() -> void:
	_refresh_queued = false
	var to_remove: Array[Node] = []
	for child: Node in get_children():
		if child is EditorStateMachineStateNode or child is EditorStateMachineEntryExitNode:
			to_remove.append(child)
	for node: Node in to_remove:
		node.free()
	clear_connections()
	_node_to_state.clear()
	_state_to_node.clear()
	_alias_ids.clear()
	var sm: StateMachine = _sm()
	if not sm:
		connection_overlay.queue_redraw()
		return
	var data: Dictionary = _load_sidecar()
	_routes = data.get("routes", {}) as Dictionary
	_build_state_nodes(data)
	_spawn_alias_nodes(data)
	_spawn_entry_node(data)
	_build_connections()
	_validate_selected_transition()
	sm._editor_watch_states()
	connection_overlay.queue_redraw()


func _reload() -> void:
	var to_remove: Array[Node] = []
	for child: Node in get_children():
		if child is GraphElement:
			to_remove.append(child)
	for node: Node in to_remove:
		node.free()
	clear_connections()
	_node_to_state.clear()
	_state_to_node.clear()
	_alias_ids.clear()
	_routes = {}
	_selected_transition = null
	_selected_wire.clear()
	_end_detach()
	var sm: StateMachine = _sm()
	if not sm:
		connection_overlay.queue_redraw()
		return
	var data: Dictionary = _load_sidecar()
	_routes = data.get("routes", {}) as Dictionary
	scroll_offset = _read_vec2(data.get("scroll_offset", []), scroll_offset)
	zoom = float(data.get("zoom", zoom))
	_spawn_annotations(data)
	_build_state_nodes(data)
	_spawn_alias_nodes(data)
	_spawn_entry_node(data)
	_build_connections()
	sm._editor_watch_states()
	connection_overlay.queue_redraw()


func _build_state_nodes(data: Dictionary) -> void:
	var sm: StateMachine = _sm()
	var states: Array[State] = []
	_collect_states(sm, states)
	var positions: Dictionary = data.get("states", {}) as Dictionary
	var auto_index: int = 0
	for s: State in states:
		var node: EditorStateMachineStateNode = SCENE_STATE_NODE.instantiate()
		var node_name: StringName = StringName(str(s.get_instance_id()))
		node.name = node_name
		node.state = s
		node.editor = state_machine_editor
		var relpath: String = String(sm.get_path_to(s))
		var fallback: Vector2 = Vector2(float(auto_index % 6) * 260.0, float(auto_index / 6) * 140.0)
		node.position_offset = _read_vec2(positions.get(relpath, []), fallback)
		node.position_offset_changed.connect(_on_state_node_moved, CONNECT_DEFERRED)
		node.node_selected.connect(_on_state_node_selected.bind(node))
		if not s.renamed.is_connected(_on_external_state_renamed):
			s.renamed.connect(_on_external_state_renamed)
		add_child(node)
		_node_to_state[node_name] = s
		_state_to_node[s] = node_name
		auto_index += 1


func _on_external_state_renamed() -> void:
	_refresh()


func _spawn_alias_nodes(data: Dictionary) -> void:
	var sm: StateMachine = _sm()
	var aliases: Dictionary = data.get("aliases", {}) as Dictionary
	for alias_id: Variant in aliases:
		var entry: Variant = aliases.get(alias_id)
		if not entry is Dictionary:
			continue
		var alias: Dictionary = entry
		var state: State = sm.get_node_or_null(NodePath(String(alias.get("state", "")))) as State
		if not state:
			continue
		_spawn_alias_node(String(alias_id), state, _read_vec2(alias.get("position", []), Vector2.ZERO))


func _spawn_alias_node(alias_id: String, state: State, pos: Vector2) -> void:
	var node: EditorStateMachineStateNode = SCENE_STATE_NODE.instantiate()
	var node_name: StringName = StringName("alias_" + alias_id)
	node.name = node_name
	node.state = state
	node.editor = state_machine_editor
	node.is_alias = true
	node.position_offset = pos
	node.position_offset_changed.connect(_on_state_node_moved, CONNECT_DEFERRED)
	node.node_selected.connect(_on_state_node_selected.bind(node))
	add_child(node)
	_node_to_state[node_name] = state
	_alias_ids[node_name] = alias_id


func _build_connections() -> void:
	var sm: StateMachine = _sm()
	for s: State in _state_to_node:
		var parent: Node = s.get_parent()
		if parent is State and _state_to_node.has(parent):
			connect_node(_state_to_node.get(parent), PORT_SUPERSTATE, _state_to_node.get(s), PORT_SUPERSTATE)
		for t: StateTransition in s.transitions:
			if not t:
				continue
			var target: State = sm.get_node_or_null(t.target) as State
			if not target or not _state_to_node.has(target):
				continue
			var route: Dictionary = _routes.get(_route_key(s, target), {})
			var from_name: StringName = _routed_endpoint(s, route, "from")
			var to_name: StringName = _routed_endpoint(target, route, "to")
			if not is_node_connected(from_name, PORT_TRANSITION, to_name, PORT_TRANSITION):
				connect_node(from_name, PORT_TRANSITION, to_name, PORT_TRANSITION)
	if sm.initial_state and _state_to_node.has(sm.initial_state) and get_node_or_null(^"entry"):
		connect_node(&"entry", PORT_TRANSITION, _state_to_node.get(sm.initial_state), PORT_TRANSITION)


func focus_transition(from_state: State, t: StateTransition, to_state: State) -> void:
	_selected_transition = t
	_selected_wire.clear()
	if to_state and _state_to_node.has(from_state) and _state_to_node.has(to_state):
		var route: Dictionary = _routes.get(_route_key(from_state, to_state), {})
		var from_name: StringName = _routed_endpoint(from_state, route, "from")
		var to_name: StringName = _routed_endpoint(to_state, route, "to")
		_selected_wire = [from_name, to_name]
		var from_card: GraphNode = get_node_or_null(NodePath(from_name)) as GraphNode
		var to_card: GraphNode = get_node_or_null(NodePath(to_name)) as GraphNode
		if from_card and to_card:
			var mid: Vector2 = (from_card.position_offset + from_card.size * 0.5 + to_card.position_offset + to_card.size * 0.5) * 0.5
			scroll_offset = mid * zoom - size * 0.5
	connection_overlay.queue_redraw()


func _validate_selected_transition() -> void:
	if not _selected_transition:
		return
	var sm: StateMachine = _sm()
	var states: Array[State] = []
	_collect_states(sm, states)
	for s: State in states:
		if s.transitions.has(_selected_transition):
			return
	_selected_transition = null
	_selected_wire.clear()


func _spawn_entry_node(data: Dictionary) -> void:
	if get_node_or_null(^"entry"):
		return
	var node: EditorStateMachineEntryExitNode = SCENE_ENTRY_NODE.instantiate()
	node.name = "entry"
	node.is_entry = true
	node.editor = state_machine_editor
	node.position_offset = _read_vec2(data.get("entry_position", []), Vector2.ZERO)
	add_child(node)
	node.position_offset_changed.connect(_queue_save_layout, CONNECT_DEFERRED)


func _spawn_annotations(data: Dictionary) -> void:
	var annotations: Array = data.get("annotations", []) as Array
	for entry: Variant in annotations:
		if entry is Dictionary:
			var text: String = String((entry as Dictionary).get("text", ""))
			var pos: Vector2 = _read_vec2((entry as Dictionary).get("position", []), Vector2.ZERO)
			_spawn_annotation(text, pos)


func _spawn_annotation(text: String, pos: Vector2) -> void:
	var node: EditorStateMachineAnnotation = SCENE_ANNOTATION.instantiate()
	node.position_offset = pos
	add_child(node)
	node.text = text
	node.position_offset_changed.connect(_queue_save_layout, CONNECT_DEFERRED)


func _on_state_node_moved() -> void:
	connection_overlay.queue_redraw()
	_queue_save_layout()


func _on_state_node_selected(node: EditorStateMachineStateNode) -> void:
	_selected_transition = null
	_selected_wire.clear()
	connection_overlay.queue_redraw()
	node._on_node_selected()


func _queue_save_layout() -> void:
	if _save_queued or not is_inside_tree():
		return
	_save_queued = true
	_flush_save_layout.call_deferred()


func _flush_save_layout() -> void:
	_save_queued = false
	_save_layout()


func _save_layout() -> void:
	var sm: StateMachine = _sm()
	if not sm:
		return
	var states: Dictionary = {}
	var aliases: Dictionary = {}
	var annotations: Array = []
	var entry_pos: Array = [0.0, 0.0]
	for child: Node in get_children():
		if child is EditorStateMachineStateNode:
			var node: EditorStateMachineStateNode = child
			if not is_instance_valid(node.state):
				continue
			if node.is_alias:
				var alias_id: String = _alias_ids.get(node.name, "")
				if not alias_id.is_empty():
					aliases[alias_id] = {
						"state": String(sm.get_path_to(node.state)),
						"position": [node.position_offset.x, node.position_offset.y],
					}
			else:
				states[String(sm.get_path_to(node.state))] = [node.position_offset.x, node.position_offset.y]
		elif child is EditorStateMachineAnnotation:
			var anno: EditorStateMachineAnnotation = child
			annotations.append({"text": anno.text, "position": [anno.position_offset.x, anno.position_offset.y]})
		elif child is EditorStateMachineEntryExitNode:
			entry_pos = [child.position_offset.x, child.position_offset.y]
	var data: Dictionary = {
		"states": states,
		"aliases": aliases,
		"routes": _pruned_routes(aliases),
		"annotations": annotations,
		"scroll_offset": [scroll_offset.x, scroll_offset.y],
		"zoom": zoom,
		"entry_position": entry_pos,
	}
	_save_sidecar(data)


func _pruned_routes(aliases: Dictionary) -> Dictionary:
	var sm: StateMachine = _sm()
	var result: Dictionary = {}
	for key: Variant in _routes:
		var text: String = String(key)
		if text.get_slice_count(" -> ") != 2:
			continue
		var from_rel: String = text.get_slice(" -> ", 0)
		var to_rel: String = text.get_slice(" -> ", 1)
		if not sm.get_node_or_null(NodePath(from_rel)) is State or not sm.get_node_or_null(NodePath(to_rel)) is State:
			continue
		var route: Dictionary = _routes.get(key)
		var valid: bool = true
		for side: String in ["from", "to"]:
			if route.has(side) and not aliases.has(route.get(side)):
				valid = false
		if valid:
			result[key] = route
	return result


func _sidecar_path() -> String:
	var sm: StateMachine = _sm()
	if not sm:
		return ""
	var root: Node = sm.owner if sm.owner else sm
	var scene_path: String = root.scene_file_path
	if scene_path.is_empty():
		return ""
	return scene_path + ".redux-layout.json"


func _load_sidecar() -> Dictionary:
	var path: String = _sidecar_path()
	if path.is_empty() or not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var text: String = file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed as Dictionary
	return {}


func _save_sidecar(data: Dictionary) -> void:
	var path: String = _sidecar_path()
	if path.is_empty():
		return
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	if not file:
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _read_vec2(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() >= 2:
		var arr: Array = value
		return Vector2(float(arr.get(0)), float(arr.get(1)))
	return fallback


func _try_inspect_connection(mouse_pos: Vector2) -> void:
	for conn: Dictionary in get_connection_list():
		if int(conn.get("from_port")) != PORT_TRANSITION or int(conn.get("to_port")) != PORT_TRANSITION:
			continue
		var from_name: StringName = StringName(conn.get("from_node"))
		var to_name: StringName = StringName(conn.get("to_node"))
		if not _node_to_state.has(from_name) or not _node_to_state.has(to_name):
			continue
		var from: GraphNode = get_node_or_null(NodePath(from_name)) as GraphNode
		var to: GraphNode = get_node_or_null(NodePath(to_name)) as GraphNode
		if not from or not to:
			continue
		var from_pos: Vector2 = (from.position_offset + from.get_output_port_position(0)) * zoom - scroll_offset
		var to_pos: Vector2 = (to.position_offset + to.get_input_port_position(0)) * zoom - scroll_offset
		var mid: Vector2 = _bezier_midpoint(from_pos, to_pos)
		if mouse_pos.distance_to(mid) >= 12.0:
			continue
		var t: StateTransition = _find_transition(_node_to_state.get(from_name), _node_to_state.get(to_name))
		if t:
			_selected_transition = t
			_selected_wire = [from_name, to_name]
			EditorInterface.inspect_object(t)
			connection_overlay.queue_redraw()
			return
	_selected_transition = null
	_selected_wire.clear()
	connection_overlay.queue_redraw()


func _on_overlay_draw() -> void:
	for conn: Dictionary in get_connection_list():
		if int(conn.get("from_port")) != PORT_TRANSITION or int(conn.get("to_port")) != PORT_TRANSITION:
			continue
		var from_name: StringName = StringName(conn.get("from_node"))
		var to_name: StringName = StringName(conn.get("to_node"))
		if not _node_to_state.has(from_name) or not _node_to_state.has(to_name):
			continue
		var from: GraphNode = get_node_or_null(NodePath(from_name)) as GraphNode
		var to: GraphNode = get_node_or_null(NodePath(to_name)) as GraphNode
		if not from or not to:
			continue
		_draw_connection_chevron(from, to, _is_selected_connection(from_name, to_name))


func _is_selected_connection(from_name: StringName, to_name: StringName) -> bool:
	if not is_instance_valid(_selected_transition) or _selected_wire.size() != 2:
		return false
	return _selected_wire.get(0) == from_name and _selected_wire.get(1) == to_name


func _draw_connection_chevron(from: GraphNode, to: GraphNode, is_selected: bool) -> void:
	var from_pos: Vector2 = (from.position_offset + from.get_output_port_position(0)) * zoom - scroll_offset
	var to_pos: Vector2 = (to.position_offset + to.get_input_port_position(0)) * zoom - scroll_offset
	var mid: Vector2 = _bezier_midpoint(from_pos, to_pos)
	var mid_tangent: Vector2 = _bezier_midtangent(from_pos, to_pos).normalized()
	var perp: Vector2 = Vector2(-mid_tangent.y, mid_tangent.x)
	var size: float = 9.0 if is_selected else 7.0
	var tip: Vector2 = mid + mid_tangent * size
	var left: Vector2 = mid - mid_tangent * size * 0.5 + perp * size
	var right: Vector2 = mid - mid_tangent * size * 0.5 - perp * size
	var col: Color = Color(0.376, 0.780, 0.647) if is_selected else Color(1.0, 1.0, 1.0, 0.85)
	connection_overlay.draw_colored_polygon(PackedVector2Array([left, tip, right]), col)


func _bezier_control_offset(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var tangent: float = min(200.0, from_pos.distance_to(to_pos) * 0.5) * zoom
	return Vector2(tangent, 0.0)


func _bezier_midpoint(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var offset: Vector2 = _bezier_control_offset(from_pos, to_pos)
	return _bezier_point(from_pos, from_pos + offset, to_pos - offset, to_pos, 0.5)


func _bezier_midtangent(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var offset: Vector2 = _bezier_control_offset(from_pos, to_pos)
	return _bezier_tangent(from_pos, from_pos + offset, to_pos - offset, to_pos, 0.5)


func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


func _bezier_tangent(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return 3.0 * u * u * (p1 - p0) + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)
