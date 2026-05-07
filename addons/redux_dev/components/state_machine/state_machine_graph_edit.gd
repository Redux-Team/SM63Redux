@tool
class_name EditorStateMachineGraphEdit
extends GraphEdit


const SCENE_STATE_NODE = preload("uid://lw2tqa550ufn")
const SCENE_ANNOTATION = preload("uid://cxlnpbgvix7ms")
const SCENE_ENTRY_NODE = preload("uid://cc2qqqr86hdcx")
const SCENE_EXIT_NODE = preload("uid://bylae6s56vffn")
const COLOR_ENTRY_EXIT: Color = Color(0.929, 0.686, 0.196)
const PORT_TRANSITION_OUT: int = 0
const PORT_TRANSITION_IN: int = 0
const PORT_SUPERSTATE: int = 1

const MENU_ITEMS: Dictionary[String, MenuItem] = {
	"+ State": MenuItem.NEW_STATE,
	"+ Annotation": MenuItem.NEW_ANNOTATION,
	"+ Alias": MenuItem.NEW_ALIAS,
}

enum MenuItem {
	NEW_STATE,
	NEW_ANNOTATION,
	NEW_ALIAS,
	NEW_ENTRY,
	NEW_EXIT,
}

@export var add_node_menu: PopupMenu
@export var add_state_dialog: AcceptDialog
@export var add_annotation_dialog: AcceptDialog
@export var state_machine_editor: EditorStateMachineEditor
@export var new_state_name_input: LineEdit
@export var new_annotation_input: LineEdit
@export var connection_overlay: Control

var _popup_pos: Vector2
var _selected_transition_tid: StringName = ""
var _transition_wire_cache: Dictionary[StringName, Array] = {}


func _init() -> void:
	delete_nodes_request.connect(_on_delete_nodes_request)


func _ready() -> void:
	if not owner._is_plugin_instance():
		return
	
	add_node_menu.clear()
	for i: int in MENU_ITEMS.size():
		add_node_menu.add_item(MENU_ITEMS.keys()[i], i)
	
	connection_request.connect(_on_connection_request)
	disconnection_request.connect(_on_disconnection_request)
	connection_to_empty.connect(_on_connection_to_empty)
	connection_overlay.draw.connect(_on_overlay_draw)


func _sm() -> StateMachine:
	return state_machine_editor._current_sm


func _resolve_uuid(uuid: StringName) -> StringName:
	var data: Dictionary = _sm().__aliases.get(uuid, {})
	return data.get("original_uuid", uuid)


func _find_node_by_uuid(uuid: StringName) -> EditorStateMachineStateNode:
	return get_node_or_null(NodePath(uuid)) as EditorStateMachineStateNode


func _find_node_by_resolved_uuid(logical_uuid: StringName) -> EditorStateMachineStateNode:
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if node and _resolve_uuid(node.uuid) == logical_uuid:
			return node
	return null


func _find_graph_node_for_logical(logical_uuid: StringName) -> EditorStateMachineStateNode:
	var node: EditorStateMachineStateNode = _find_node_by_uuid(logical_uuid)
	if node:
		return node
	return _find_node_by_resolved_uuid(logical_uuid)


func _on_overlay_draw() -> void:
	for conn: Dictionary in get_connection_list():
		if conn.from_port != 0 or conn.to_port != 0:
			continue
		var from: GraphNode = get_node_or_null(NodePath(conn.from_node)) as GraphNode
		var to: GraphNode = get_node_or_null(NodePath(conn.to_node)) as GraphNode
		if not from or not to:
			continue
		
		var logical_from: StringName = _resolve_uuid(StringName(conn.from_node))
		var logical_to: StringName = _resolve_uuid(StringName(conn.to_node))
		var is_selected: bool = false
		for tid: StringName in _sm().__transitions:
			var t: StateTransition = _sm().__transitions.get(tid) as StateTransition
			if not t:
				continue
			if t.__from_uuid == logical_from and t.__to_uuid == logical_to:
				is_selected = tid == _selected_transition_tid
				break
		
		_draw_connection_chevron(from, to, is_selected)


func _draw_connection_chevron(from: GraphNode, to: GraphNode, is_selected: bool) -> void:
	var from_pos: Vector2 = (from.position_offset + from.get_output_port_position(0)) * zoom - scroll_offset
	var to_pos: Vector2 = (to.position_offset + to.get_input_port_position(0)) * zoom - scroll_offset
	var mid: Vector2 = _bezier_midpoint(from_pos, to_pos)
	var mid_tangent: Vector2 = _bezier_midtangent(from_pos, to_pos).normalized()
	var perp: Vector2 = Vector2(-mid_tangent.y, mid_tangent.x)
	var size: float = 7.0 if not is_selected else 9.0
	var tip: Vector2 = mid + mid_tangent * size
	var left: Vector2 = mid - mid_tangent * size * 0.5 + perp * size
	var right: Vector2 = mid - mid_tangent * size * 0.5 - perp * size
	var col: Color = Color(0.376, 0.780, 0.647) if is_selected else Color(1.0, 1.0, 1.0, 0.85)
	connection_overlay.draw_colored_polygon(PackedVector2Array([left, tip, right]), col)


func _bezier_cp(from_pos: Vector2, to_pos: Vector2) -> Array[Vector2]:
	var tangent: float = min(200.0, from_pos.distance_to(to_pos) * 0.5) * zoom
	var result: Array[Vector2] = [from_pos + Vector2(tangent, 0.0), to_pos - Vector2(tangent, 0.0)]
	return result


func _bezier_midpoint(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var cp: Array[Vector2] = _bezier_cp(from_pos, to_pos)
	return _bezier_point(from_pos, cp[0], cp[1], to_pos, 0.5)


func _bezier_midtangent(from_pos: Vector2, to_pos: Vector2) -> Vector2:
	var cp: Array[Vector2] = _bezier_cp(from_pos, to_pos)
	return _bezier_tangent(from_pos, cp[0], cp[1], to_pos, 0.5)


func _bezier_point(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return u * u * u * p0 + 3.0 * u * u * t * p1 + 3.0 * u * t * t * p2 + t * t * t * p3


func _bezier_tangent(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u: float = 1.0 - t
	return 3.0 * u * u * (p1 - p0) + 6.0 * u * t * (p2 - p1) + 3.0 * t * t * (p3 - p2)


func _on_connection_request(from_node: StringName, from_slot: int, to_node: StringName, to_slot: int) -> void:
	var from: Node = get_node_or_null(NodePath(from_node))
	var to: Node = get_node_or_null(NodePath(to_node))
	if not from or not to or from == to:
		return
	
	if from is EditorStateMachineEntryExitNode and from.is_entry and to is EditorStateMachineStateNode:
		_sm().__entry_target_uuid = _resolve_uuid(StringName(to_node))
		if is_node_connected(from_node, 0, to_node, 0):
			disconnect_node(from_node, 0, to_node, 0)
		connect_node(from_node, 0, to_node, 0, true)
		return
	
	if from is EditorStateMachineStateNode and to is EditorStateMachineEntryExitNode and not to.is_entry:
		_sm().__exit_source_uuid = _resolve_uuid(StringName(from_node))
		if is_node_connected(from_node, 0, to_node, 0):
			disconnect_node(from_node, 0, to_node, 0)
		connect_node(from_node, 0, to_node, 0, true)
		return
	
	var from_state: EditorStateMachineStateNode = from as EditorStateMachineStateNode
	var to_state: EditorStateMachineStateNode = to as EditorStateMachineStateNode
	if not from_state or not to_state:
		return
	
	if from_slot == 0 and to_slot == 1:
		_connect_superstate(from_state, to_state)
	elif from_slot == 0 and to_slot == 0:
		_connect_transition(from_state, to_state)
	elif from_slot == 1 and to_slot == 1 and not from_state.superstate_uuid.is_empty():
		var wire_from: EditorStateMachineStateNode = _find_node_by_uuid(from_state.superstate_uuid)
		if not wire_from:
			return
		to_state._set_superstate(from_state.superstate_uuid)
		var state: State = _sm().__states.get(to_state.uuid)
		if state:
			state.__editor_superstate_wire_uuid = from_state.uuid
		var parent_state: State = _sm().__states.get(_resolve_uuid(from_state.superstate_uuid))
		var to_resolved: State = _sm().__states.get(_resolve_uuid(to_state.uuid))
		if parent_state and to_resolved:
			to_resolved.get_parent().remove_child(to_resolved)
			parent_state.add_child(to_resolved)
			to_resolved.owner = _sm().owner
		connect_node(from_node, 1, to_node, 1, true)


func _on_disconnection_request(from_node: StringName, from_slot: int, to_node: StringName, to_slot: int) -> void:
	if from_slot == 0 and to_slot == 1:
		var to: EditorStateMachineStateNode = _find_node_by_uuid(StringName(to_node))
		if not to:
			return
		_detach_superstate(to)
		disconnect_node(from_node, from_slot, to_node, to_slot)
	elif from_slot == 0 and to_slot == 0:
		var from: EditorStateMachineStateNode = _find_node_by_uuid(StringName(from_node))
		var to: EditorStateMachineStateNode = _find_node_by_uuid(StringName(to_node))
		if not from or not to:
			return
		_remove_transition(_resolve_uuid(from.uuid), _resolve_uuid(to.uuid))
		disconnect_node(from_node, from_slot, to_node, to_slot)
	elif from_slot == 1 and to_slot == 1:
		var to: EditorStateMachineStateNode = _find_node_by_uuid(StringName(to_node))
		if not to:
			return
		_detach_superstate(to)
		disconnect_node(from_node, from_slot, to_node, to_slot)


func _detach_superstate(node: EditorStateMachineStateNode) -> void:
	node._set_superstate("")
	var state: State = _sm().__states.get(_resolve_uuid(node.uuid))
	if state:
		state.get_parent().remove_child(state)
		_sm().add_child(state)
		state.owner = _sm().owner


func _connect_transition(from: EditorStateMachineStateNode, to: EditorStateMachineStateNode) -> void:
	var logical_from: StringName = _resolve_uuid(from.uuid)
	var logical_to: StringName = _resolve_uuid(to.uuid)
	if _transition_exists(logical_from, logical_to):
		return
	
	var tid: StringName = StringName(Packer.generate_uuid())
	var transition: StateTransition = StateTransition.new()
	transition.resource_local_to_scene = true
	transition.__from_uuid = logical_from
	transition.__to_uuid = logical_to
	transition.__from_node_uuid = from.uuid
	transition.__to_node_uuid = to.uuid
	_sm().__transitions[tid] = transition
	_transition_wire_cache[tid] = [from.uuid, to.uuid]
	
	connect_node(from.uuid, 0, to.uuid, 0, true)
	queue_redraw()
	EditorInterface.inspect_object(transition)


func _connect_superstate(from: EditorStateMachineStateNode, to: EditorStateMachineStateNode) -> void:
	for conn: Dictionary in get_connection_list():
		if conn.from_node == StringName(from.uuid) and conn.from_port == 0 and conn.to_port == 1:
			disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
			break
	
	to._set_superstate(from.uuid)
	var state: State = _sm().__states.get(to.uuid)
	if state:
		state.__editor_superstate_wire_uuid = from.uuid
	
	var from_state: State = _sm().__states.get(_resolve_uuid(from.uuid))
	var to_state: State = _sm().__states.get(_resolve_uuid(to.uuid))
	if from_state and to_state:
		to_state.get_parent().remove_child(to_state)
		from_state.add_child(to_state)
		to_state.owner = _sm().owner
	
	connect_node(from.uuid, 0, to.uuid, 1, true)


func _transition_exists(logical_from: StringName, logical_to: StringName) -> bool:
	for tid: StringName in _sm().__transitions:
		var t: StateTransition = _sm().__transitions.get(tid) as StateTransition
		if t.__from_uuid == logical_from and t.__to_uuid == logical_to:
			return true
	return false


func _remove_transition(logical_from: StringName, logical_to: StringName) -> void:
	for tid: StringName in _sm().__transitions:
		var t: StateTransition = _sm().__transitions.get(tid) as StateTransition
		if t.__from_uuid == logical_from and t.__to_uuid == logical_to:
			_sm().__transitions.erase(tid)
			_transition_wire_cache.erase(tid)
			return


func _restore_connections() -> void:
	if _sm().__has_entry:
		_spawn_entry_node()
	if _sm().__has_exit:
		_spawn_exit_node()
	
	if not _sm().__entry_target_uuid.is_empty():
		var target: EditorStateMachineStateNode = _find_graph_node_for_logical(_sm().__entry_target_uuid)
		if target:
			connect_node("entry", 0, target.uuid, 0, true)
	
	if not _sm().__exit_source_uuid.is_empty():
		var source: EditorStateMachineStateNode = _find_graph_node_for_logical(_sm().__exit_source_uuid)
		if source:
			connect_node(source.uuid, 0, "exit", 0, true)
	
	for tid: StringName in _sm().__transitions:
		var t: StateTransition = _sm().__transitions.get(tid) as StateTransition
		if not t:
			continue
		var wire: Array = _transition_wire_cache.get(tid, [])
		var from_node_uuid: StringName = wire[0] if wire.size() > 0 else t.__from_node_uuid
		var to_node_uuid: StringName = wire[1] if wire.size() > 1 else t.__to_node_uuid
		if from_node_uuid.is_empty():
			from_node_uuid = t.__from_uuid
		if to_node_uuid.is_empty():
			to_node_uuid = t.__to_uuid
		var from: EditorStateMachineStateNode = _find_node_by_uuid(from_node_uuid)
		if not from:
			from = _find_graph_node_for_logical(t.__from_uuid)
		var to: EditorStateMachineStateNode = _find_node_by_uuid(to_node_uuid)
		if not to:
			to = _find_graph_node_for_logical(t.__to_uuid)
		if from and to:
			connect_node(from.uuid, 0, to.uuid, 0, true)
	
	for uuid: StringName in _sm().__states:
		var state: State = _sm().__states.get(uuid) as State
		if not state or state.__editor_superstate_uuid.is_empty():
			continue
		var to: EditorStateMachineStateNode = _find_node_by_uuid(uuid)
		var wire_from: EditorStateMachineStateNode = _find_node_by_uuid(state.__editor_superstate_wire_uuid)
		if not to or not wire_from:
			continue
		wire_from._set_entry_port_enabled(true)
		var is_sibling: bool = wire_from.uuid != state.__editor_superstate_uuid
		if is_sibling:
			connect_node(wire_from.uuid, 1, to.uuid, 1, true)
		else:
			connect_node(wire_from.uuid, 0, to.uuid, 1, true)
	
	connection_overlay.queue_redraw()


func _on_connection_to_empty(from_node: StringName, from_slot: int, _release_pos: Vector2) -> void:
	if from_slot == PORT_TRANSITION_OUT and _find_node_by_uuid(from_node):
		EditorInterface.inspect_object(null)


func _clear_superstate_references(deleted_uuid: StringName) -> void:
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if node and node.superstate_uuid == deleted_uuid:
			node._set_superstate("")


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rebuild_add_menu()
		add_node_menu.position = event.global_position
		add_node_menu.popup()
		_popup_pos = (event.position + scroll_offset) / zoom
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_inspect_connection(event.position)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		_try_open_connection_script(event.position)
	
	_sm().__last__editor_position = scroll_offset
	_sm().__last_editor_zoom = zoom
	connection_overlay.queue_redraw()


func _try_open_connection_script(mouse_pos: Vector2) -> void:
	for conn: Dictionary in get_connection_list():
		if conn.from_port != 0 or conn.to_port != 0:
			continue
		var from: GraphNode = get_node_or_null(NodePath(conn.from_node)) as GraphNode
		var to: GraphNode = get_node_or_null(NodePath(conn.to_node)) as GraphNode
		if not from or not to:
			continue
		
		var from_pos: Vector2 = (from.position_offset + from.get_output_port_position(0)) * zoom - scroll_offset
		var to_pos: Vector2 = (to.position_offset + to.get_input_port_position(0)) * zoom - scroll_offset
		var mid: Vector2 = _bezier_midpoint(from_pos, to_pos)
		if mouse_pos.distance_to(mid) >= 12.0:
			continue
		
		var logical_from: StringName = _resolve_uuid(StringName(conn.from_node))
		var logical_to: StringName = _resolve_uuid(StringName(conn.to_node))
		for tid: StringName in _sm().__transitions:
			var t: StateTransition = _sm().__transitions.get(tid) as StateTransition
			if not t:
				continue
			if t.__from_uuid == logical_from and t.__to_uuid == logical_to:
				EditorStateMachineEditor.prompt_transition_script(t)
				return


func _try_inspect_connection(mouse_pos: Vector2) -> void:
	for conn: Dictionary in get_connection_list():
		if conn.from_port != 0 or conn.to_port != 0:
			continue
		var from: GraphNode = get_node_or_null(NodePath(conn.from_node)) as GraphNode
		var to: GraphNode = get_node_or_null(NodePath(conn.to_node)) as GraphNode
		if not from or not to:
			continue
		
		var from_pos: Vector2 = (from.position_offset + from.get_output_port_position(0)) * zoom - scroll_offset
		var to_pos: Vector2 = (to.position_offset + to.get_input_port_position(0)) * zoom - scroll_offset
		var mid: Vector2 = _bezier_midpoint(from_pos, to_pos)
		if mouse_pos.distance_to(mid) >= 12.0:
			continue
		
		var logical_from: StringName = _resolve_uuid(StringName(conn.from_node))
		var logical_to: StringName = _resolve_uuid(StringName(conn.to_node))
		for tid: StringName in _sm().__transitions:
			var t: StateTransition = _sm().__transitions.get(tid) as StateTransition
			if not t:
				continue
			if t.__from_uuid == logical_from and t.__to_uuid == logical_to:
				_selected_transition_tid = tid
				EditorInterface.inspect_object(t)
				connection_overlay.queue_redraw()
				return
	
	_selected_transition_tid = ""
	connection_overlay.queue_redraw()


func _rebuild_add_menu() -> void:
	var selected_state: EditorStateMachineStateNode
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if node and node.selected:
			if selected_state:
				selected_state = null
				break
			selected_state = node
	
	add_node_menu.clear()
	add_node_menu.add_item("+ State", MenuItem.NEW_STATE)
	if selected_state:
		add_node_menu.add_item("+ Alias", MenuItem.NEW_ALIAS)
	add_node_menu.add_item("+ Annotation", MenuItem.NEW_ANNOTATION)
	add_node_menu.add_item("+ Entry", MenuItem.NEW_ENTRY)
	add_node_menu.add_item("+ Exit", MenuItem.NEW_EXIT)


func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	_on_state_node_deselected()
	for node_name: StringName in node_names:
		var node: Node = find_child(node_name, false, false)
		if not node:
			continue
		
		if node is EditorStateMachineStateNode:
			if not node.alias_of.is_empty():
				_remove_alias(node.uuid)
			else:
				_remove_state(node.uuid)
				_clear_superstate_references(node.uuid)
		elif node is EditorStateMachineAnnotation:
			_remove_annotation(node.uuid)
		elif node is EditorStateMachineEntryExitNode:
			if node.is_entry:
				_sm().__has_entry = false
				_sm().__entry_target_uuid = ""
			else:
				_sm().__has_exit = false
				_sm().__exit_source_uuid = ""
		
		node.queue_free()


func _on_add_node_menu_id_pressed(id: int) -> void:
	match id:
		MenuItem.NEW_STATE:
			add_state_dialog.popup_centered()
		MenuItem.NEW_ALIAS:
			_try_add_alias()
		MenuItem.NEW_ANNOTATION:
			add_annotation_dialog.popup_centered()
		MenuItem.NEW_ENTRY:
			_add_entry_node()
		MenuItem.NEW_EXIT:
			_add_exit_node()


func _try_add_alias() -> void:
	var selected: EditorStateMachineStateNode
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if node and node.selected:
			selected = node
			break
	if not selected:
		EditorInterface.get_editor_toaster().push_toast("Select a state node first to create an alias.")
		return
	_add_alias(_resolve_uuid(selected.uuid), _popup_pos)


func _add_alias(original_uuid: StringName, pos: Vector2) -> void:
	var alias_uuid: StringName = StringName(Packer.generate_uuid())
	_sm().__aliases[alias_uuid] = { "original_uuid": original_uuid, "position": pos }
	_spawn_alias_node(alias_uuid)


func _remove_alias(alias_uuid: StringName) -> void:
	_sm().__aliases.erase(alias_uuid)


func _add_entry_node() -> void:
	if _sm().__has_entry:
		EditorInterface.get_editor_toaster().push_toast("An entry node already exists.")
		return
	_sm().__has_entry = true
	_sm().__entry_node_position = _popup_pos
	_spawn_entry_node()


func _add_exit_node() -> void:
	if _sm().__has_exit:
		EditorInterface.get_editor_toaster().push_toast("An exit node already exists.")
		return
	_sm().__has_exit = true
	_sm().__exit_node_position = _popup_pos
	_spawn_exit_node()


func _spawn_entry_node() -> void:
	if get_node_or_null("entry"):
		return
	var node: EditorStateMachineEntryExitNode = SCENE_ENTRY_NODE.instantiate()
	node.name = "entry"
	node.position_offset = _sm().__entry_node_position
	node.is_entry = true
	node.editor = owner
	node.position_offset_changed.connect(func() -> void:
		_sm().__entry_node_position = node.position_offset)
	node.node_selected.connect(_on_entry_exit_selected.bind(node))
	add_child(node)


func _spawn_exit_node() -> void:
	if get_node_or_null("exit"):
		return
	var node: EditorStateMachineEntryExitNode = SCENE_EXIT_NODE.instantiate()
	node.name = "exit"
	node.position_offset = _sm().__exit_node_position
	node.is_entry = false
	node.editor = owner
	node.position_offset_changed.connect(func() -> void:
		_sm().__exit_node_position = node.position_offset)
	node.node_selected.connect(_on_entry_exit_selected.bind(node))
	add_child(node)


func _on_entry_exit_selected(_node: EditorStateMachineEntryExitNode) -> void:
	EditorInterface.inspect_object(null)


func _spawn_alias_node(alias_uuid: StringName) -> void:
	var data: Dictionary = _sm().__aliases.get(alias_uuid, {})
	if data.is_empty():
		return
	var original_uuid: StringName = data.get("original_uuid", "")
	var state: State = _sm().__states.get(original_uuid)
	if not state:
		return
	
	var node: EditorStateMachineStateNode = SCENE_STATE_NODE.instantiate()
	node.name = alias_uuid
	node.uuid = alias_uuid
	node.alias_of = original_uuid
	node.title = state.__editor_name
	node.position_offset = data.get("position", Vector2.ZERO)
	node.superstate_uuid = state.__editor_superstate_uuid
	node.editor = owner
	node.position_offset_changed.connect(_on_state_node_moved.bind(node), CONNECT_DEFERRED)
	node.node_selected.connect(_on_state_node_selected.bind(node))
	node.node_deselected.connect(_on_state_node_deselected)
	add_child(node)


func _on_add_state_dialog_confirmed() -> void:
	var label: String = new_state_name_input.text.strip_edges()
	new_state_name_input.text = ""
	if label.is_empty():
		return
	if _state_label_exists(label):
		EditorInterface.get_editor_toaster().push_toast("A state with that name already exists!")
		return
	_add_state(label, _popup_pos)


func _on_add_annotation_dialog_confirmed() -> void:
	var text: String = new_annotation_input.text.strip_edges()
	new_annotation_input.text = ""
	if text.is_empty():
		return
	_add_annotation(text, _popup_pos)


func _state_label_exists(label: String) -> bool:
	for uuid: StringName in _sm().__states:
		var state: State = _sm().__states.get(uuid)
		if state.__editor_name == label:
			return true
	return false


func _add_state(label: String, pos: Vector2) -> void:
	var uuid: StringName = StringName(Packer.generate_uuid())
	var state: State = State.new()
	state.__editor_name = label
	state.__editor_position = pos
	state.__editor_uuid = uuid
	
	_sm().add_child(state)
	state.name = label.to_pascal_case()
	state.owner = _sm().owner
	_sm().__states[uuid] = state
	
	_spawn_state_node(uuid)


func _remove_state(uuid: StringName) -> void:
	var state: State = _sm().__states.get(uuid)
	if state:
		state.queue_free()
	_sm().__states.erase(uuid)
	for tid: StringName in _sm().__transitions.keys():
		var t: StateTransition = _sm().__transitions.get(tid)
		if t.__from_uuid == uuid or t.__to_uuid == uuid:
			_sm().__transitions.erase(tid)


func _spawn_state_node(uuid: StringName) -> void:
	var state: State = _sm().__states.get(uuid)
	if not state:
		return
	
	var node: EditorStateMachineStateNode = SCENE_STATE_NODE.instantiate()
	node.name = uuid
	node.uuid = uuid
	node.title = state.__editor_name
	node.position_offset = state.__editor_position
	node.superstate_uuid = state.__editor_superstate_uuid
	node.editor = owner
	node.position_offset_changed.connect(_on_state_node_moved.bind(node), CONNECT_DEFERRED)
	node.node_selected.connect(_on_state_node_selected.bind(node))
	node.node_deselected.connect(_on_state_node_deselected)
	add_child(node)


func _add_annotation(text: String, pos: Vector2) -> void:
	var uuid: StringName = StringName(Packer.generate_uuid())
	_sm().__annotations[uuid] = { "text": text, "position": pos }
	_spawn_annotation_node(uuid)


func _remove_annotation(uuid: StringName) -> void:
	_sm().__annotations.erase(uuid)


func _spawn_annotation_node(uuid: StringName) -> void:
	var data: Dictionary = _sm().__annotations.get(uuid, {})
	if data.is_empty():
		return
	
	var node: EditorStateMachineAnnotation = SCENE_ANNOTATION.instantiate()
	node.uuid = uuid
	node.text = data.get("text", "")
	node.position_offset = data.get("position", Vector2.ZERO)
	node.position_offset_changed.connect(_on_annotation_moved.bind(node), CONNECT_DEFERRED)
	add_child(node)


func _on_state_node_selected(node: EditorStateMachineStateNode) -> void:
	_selected_transition_tid = ""
	connection_overlay.queue_redraw()
	node._on_node_selected()
	
	var connected_uuids: Dictionary[StringName, bool] = {}
	for conn: Dictionary in get_connection_list():
		if conn.from_node == StringName(node.uuid) or conn.to_node == StringName(node.uuid):
			connected_uuids[StringName(conn.from_node)] = true
			connected_uuids[StringName(conn.to_node)] = true
	
	for conn: Dictionary in get_connection_list():
		if not connected_uuids.has(StringName(conn.from_node)) and not connected_uuids.has(StringName(conn.to_node)):
			disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
	
	for child: Node in get_children():
		var other: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if not other or other == node:
			continue
		if connected_uuids.has(StringName(other.uuid)):
			other.show()
		else:
			other.modulate.a = 0.4


func _on_state_node_deselected() -> void:
	for child: Node in get_children():
		var other: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if not other:
			continue
		other.show()
		other.modulate.a = 1.0
	
	_restore_connections()


func _on_state_node_moved(node: EditorStateMachineStateNode) -> void:
	if not node.alias_of.is_empty():
		var data: Dictionary = _sm().__aliases.get(node.uuid, {})
		data["position"] = node.position_offset
		_sm().__aliases[node.uuid] = data
	else:
		var state: State = _sm().__states.get(node.uuid)
		if state:
			state.__editor_position = node.position_offset


func _on_annotation_moved(node: EditorStateMachineAnnotation) -> void:
	var data: Dictionary = _sm().__annotations.get(node.uuid, {})
	data["position"] = node.position_offset
	_sm().__annotations[node.uuid] = data
