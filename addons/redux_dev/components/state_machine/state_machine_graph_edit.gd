@tool
class_name EditorStateMachineGraphEdit
extends GraphEdit


const SCENE_STATE_NODE = preload("uid://lw2tqa550ufn")
const SCENE_ANNOTATION = preload("uid://cxlnpbgvix7ms")
const PORT_TRANSITION_OUT := 0
const PORT_TRANSITION_IN := 0
const PORT_SUPERSTATE := 1

const MENU_ITEMS: Dictionary[String, MenuItem] = {
	"+ State": MenuItem.NEW_STATE,
	"+ Annotation": MenuItem.NEW_ANNOTATION,
	"+ Alias": MenuItem.NEW_ALIAS,
}

enum MenuItem { NEW_STATE, NEW_ANNOTATION, NEW_ALIAS }

@export var add_node_menu: PopupMenu
@export var add_state_dialog: AcceptDialog
@export var add_annotation_dialog: AcceptDialog
@export var state_machine_editor: EditorStateMachineEditor
@export var new_state_name_input: LineEdit
@export var new_annotation_input: LineEdit

var _popup_pos: Vector2


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


func _on_connection_request(from_node: StringName, from_slot: int, to_node: StringName, to_slot: int) -> void:
	var from: EditorStateMachineStateNode = _find_node_by_name(from_node)
	var to: EditorStateMachineStateNode = _find_node_by_name(to_node)
	if not from or not to or from == to:
		return
	
	if from_slot == 0 and to_slot == 1:
		_connect_superstate(from, to)
	elif from_slot == 0 and to_slot == 0:
		_connect_transition(from, to)
	elif from_slot == 1 and to_slot == 1 and not from.superstate_uuid.is_empty():
		var superstate: EditorStateMachineStateNode = _find_node_by_uuid(from.superstate_uuid)
		if not superstate:
			return
		to._set_superstate(from.superstate_uuid)
		var state: State = _sm().__states.get(to.uuid)
		if state:
			state.__editor_superstate_wire_uuid = from.uuid
		
		var parent_state: State = _sm().__states.get(_resolve_uuid(from.superstate_uuid))
		var to_state: State = _sm().__states.get(_resolve_uuid(to.uuid))
		if parent_state and to_state:
			to_state.get_parent().remove_child(to_state)
			parent_state.add_child(to_state)
			to_state.owner = _sm().owner
		
		connect_node(from.uuid, 1, to.uuid, 1, true)


func _on_disconnection_request(from_node: StringName, from_slot: int, to_node: StringName, to_slot: int) -> void:
	var from: EditorStateMachineStateNode = _find_node_by_name(from_node)
	var to: EditorStateMachineStateNode = _find_node_by_name(to_node)
	if not from or not to:
		return
	
	if from_slot == 0 and to_slot == 1:
		to._set_superstate("")
		disconnect_node(from_node, from_slot, to_node, to_slot)
		var to_state: State = _sm().__states.get(_resolve_uuid(to.uuid))
		if to_state:
			to_state.get_parent().remove_child(to_state)
			_sm().add_child(to_state)
			to_state.owner = _sm().owner
	elif from_slot == 0 and to_slot == 0:
		_remove_transition(from.uuid, to.uuid)
		disconnect_node(from_node, from_slot, to_node, to_slot)
	elif from_slot == 1 and to_slot == 1:
		to._set_superstate("")
		disconnect_node(from_node, from_slot, to_node, to_slot)


func _has_any_children(uuid: String) -> bool:
	for conn: Dictionary in get_connection_list():
		if conn.from_node == StringName(uuid) and conn.from_port == 0 and conn.to_port == 1:
			return true
	return false


func _connect_entry(from: EditorStateMachineStateNode, to: EditorStateMachineStateNode) -> void:
	_remove_entry(from.uuid)
	var state: State = _sm().__states.get(from.uuid)
	if not state:
		return
	state.__editor_entry_uuid = to.uuid
	connect_node(from.uuid, 1, to.uuid, 0, true)


func _remove_entry(from_uuid: String) -> void:
	for conn: Dictionary in get_connection_list():
		if conn.from_node == StringName(from_uuid) and conn.from_port == 1:
			disconnect_node(conn.from_node, conn.from_port, conn.to_node, conn.to_port)
			break
	var state: State = _sm().__states.get(from_uuid)
	if state:
		state.__editor_entry_uuid = ""


func _on_connection_to_empty(from_node: StringName, from_slot: int, _release_pos: Vector2) -> void:
	var from: EditorStateMachineStateNode = _find_node_by_name(from_node)
	if from_slot == PORT_TRANSITION_OUT and from:
		EditorInterface.inspect_object(null)


func _find_node_by_uuid(target_uuid: String) -> EditorStateMachineStateNode:
	return get_node_or_null(target_uuid) as EditorStateMachineStateNode


func _find_node_by_name(node_name: StringName) -> EditorStateMachineStateNode:
	return get_node_or_null(NodePath(node_name)) as EditorStateMachineStateNode


func _clear_superstate_references(deleted_uuid: String) -> void:
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if node and node.superstate_uuid == deleted_uuid:
			node._set_superstate("")


func _connect_transition(from: EditorStateMachineStateNode, to: EditorStateMachineStateNode) -> void:
	_connect_transition_visual(from, to, from.uuid, to.uuid)


func _connect_transition_visual(from: EditorStateMachineStateNode, to: EditorStateMachineStateNode, logical_from: String, logical_to: String) -> void:
	if _transition_exists(logical_from, logical_to):
		return
	
	var tid: String = Packer.generate_uuid()
	var transition: StateTransition = StateTransition.new()
	transition.__from_uuid = logical_from
	transition.__to_uuid = logical_to
	_sm().__transitions[tid] = transition
	
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


func _restore_connections() -> void:
	for uuid: String in _sm().__transitions:
		var t: StateTransition = _sm().__transitions.get(uuid)
		if not t:
			continue
		var from: EditorStateMachineStateNode = _find_node_by_uuid(t.__from_uuid)
		var to: EditorStateMachineStateNode = _find_node_by_uuid(t.__to_uuid)
		if from and to:
			connect_node(from.uuid, 0, to.uuid, 0, true)
	
	for uuid: String in _sm().__states:
		var state: State = _sm().__states.get(uuid)
		if state.__editor_superstate_uuid.is_empty():
			continue
		var to: EditorStateMachineStateNode = _find_node_by_uuid(uuid)
		var wire_from: EditorStateMachineStateNode = _find_node_by_uuid(state.__editor_superstate_wire_uuid)
		if not to or not wire_from:
			continue
		var is_sibling: bool = wire_from.uuid != state.__editor_superstate_uuid
		wire_from._set_entry_port_enabled(true)
		if is_sibling:
			connect_node(wire_from.uuid, 1, to.uuid, 1, true)
		else:
			connect_node(wire_from.uuid, 0, to.uuid, 1, true)


func _remove_transition(__from_uuid: String, __to_uuid: String) -> void:
	for uuid: String in _sm().__transitions:
		var t: StateTransition = _sm().__transitions.get(uuid)
		if t.__from_uuid == __from_uuid and t.__to_uuid == __to_uuid:
			_sm().__transitions.erase(uuid)
			return


func _transition_exists(__from_uuid: String, __to_uuid: String) -> bool:
	for uuid: String in _sm().__transitions:
		var t: StateTransition = _sm().__transitions.get(uuid)
		if t.__from_uuid == __from_uuid and t.__to_uuid == __to_uuid:
			return true
	return false


func _rebuild_add_menu() -> void:
	var selected_state: EditorStateMachineStateNode
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if node and node.selected and node.alias_of.is_empty():
			if selected_state:
				selected_state = null
				break
			selected_state = node
	
	add_node_menu.clear()
	add_node_menu.add_item("+ State", MenuItem.NEW_STATE)
	add_node_menu.add_item("+ Annotation", MenuItem.NEW_ANNOTATION)
	if selected_state:
		add_node_menu.add_item("+ Alias", MenuItem.NEW_ALIAS)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		_rebuild_add_menu()
		add_node_menu.position = event.global_position
		add_node_menu.popup()
		_popup_pos = (event.position + scroll_offset) / zoom
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_try_inspect_connection(event.position)
	
	_sm().__last__editor_position = scroll_offset
	_sm().__last_editor_zoom = zoom


func _find_node_by_resolved_uuid(target_uuid: String) -> EditorStateMachineStateNode:
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if node and _resolve_uuid(node.uuid) == target_uuid:
			return node
	return null


func _try_inspect_connection(mouse_pos: Vector2) -> void:
	for uuid: String in _sm().__transitions:
		var t: StateTransition = _sm().__transitions.get(uuid)
		if not t:
			continue
		var from: EditorStateMachineStateNode = _find_node_by_resolved_uuid(t.__from_uuid)
		var to: EditorStateMachineStateNode = _find_node_by_resolved_uuid(t.__to_uuid)
		if not from or not to:
			continue
		
		var from_pos: Vector2 = (from.position_offset + from.get_output_port_position(0)) * zoom - scroll_offset
		var to_pos: Vector2 = (to.position_offset + to.get_input_port_position(0)) * zoom - scroll_offset
		
		if _point_near_line(mouse_pos, from_pos, to_pos, 8.0):
			EditorInterface.inspect_object(t)
			return


func _point_near_line(point: Vector2, a: Vector2, b: Vector2, threshold: float) -> bool:
	var ab: Vector2 = b - a
	var len_sq: float = ab.length_squared()
	if len_sq == 0.0:
		return point.distance_to(a) < threshold
	var t: float = clampf((point - a).dot(ab) / len_sq, 0.0, 1.0)
	return point.distance_to(a + ab * t) < threshold


func _sm() -> StateMachine:
	return state_machine_editor._current_sm


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
		
		node.queue_free()


func _on_add_node_menu_id_pressed(id: int) -> void:
	match id:
		MenuItem.NEW_STATE:
			add_state_dialog.popup_centered()
		MenuItem.NEW_ALIAS:
			_try_add_alias()
		MenuItem.NEW_ANNOTATION:
			add_annotation_dialog.popup_centered()


func _try_add_alias() -> void:
	var selected: EditorStateMachineStateNode
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if node and node.selected and node.alias_of.is_empty():
			selected = node
			break
	if not selected:
		EditorInterface.get_editor_toaster().push_toast("Select a state node first to create an alias.")
		return
	_add_alias(selected.uuid, _popup_pos)


func _add_alias(original_uuid: String, pos: Vector2) -> void:
	var alias_uuid: String = Packer.generate_uuid()
	_sm().__aliases[alias_uuid] = { "original_uuid": original_uuid, "position": pos }
	_spawn_alias_node(alias_uuid)


func _remove_alias(alias_uuid: String) -> void:
	_sm().__aliases.erase(alias_uuid)


func _resolve_uuid(uuid: String) -> String:
	var data: Dictionary = _sm().__aliases.get(uuid, {})
	return data.get("original_uuid", uuid)


func _spawn_alias_node(alias_uuid: String) -> void:
	var data: Dictionary = _sm().__aliases.get(alias_uuid, {})
	if data.is_empty():
		return
	var original_uuid: String = data.get("original_uuid", "")
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
	for uuid: String in _sm().__states:
		var state: State = _sm().__states.get(uuid)
		if state.__editor_name == label:
			return true
	return false


func _add_state(label: String, pos: Vector2) -> void:
	var uuid: String = Packer.generate_uuid()
	var state: State = State.new()
	state.__editor_name = label
	state.__editor_position = pos
	state.__editor_uuid = uuid
	
	_sm().add_child(state)
	state.name = label.to_pascal_case()
	state.owner = _sm().owner
	_sm().__states[uuid] = state
	
	_spawn_state_node(uuid)


func _remove_state(uuid: String) -> void:
	var state: State = _sm().__states.get(uuid)
	if state:
		state.queue_free()
	_sm().__states.erase(uuid)


func _spawn_state_node(uuid: String) -> void:
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
	var uuid: String = Packer.generate_uuid()
	_sm().__annotations[uuid] = { "text": text, "position": pos }
	_spawn_annotation_node(uuid)


func _remove_annotation(uuid: String) -> void:
	_sm().__annotations.erase(uuid)


func _on_state_node_selected(node: EditorStateMachineStateNode) -> void:
	node._on_node_selected()
	var connected_uuids: Array[String] = []
	for conn: Dictionary in get_connection_list():
		if conn.from_node == StringName(node.uuid) or conn.to_node == StringName(node.uuid):
			connected_uuids.append(str(conn.from_node))
			connected_uuids.append(str(conn.to_node))
	
	for conn: Dictionary in get_connection_list():
		var from: StringName = conn.from_node
		var to: StringName = conn.to_node
		if from != StringName(node.uuid) and to != StringName(node.uuid):
			disconnect_node(from, conn.from_port, to, conn.to_port)
	
	for child: Node in get_children():
		var other: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if not other or other == node:
			continue
		if other.uuid in connected_uuids:
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


func _spawn_annotation_node(uuid: String) -> void:
	var data: Dictionary = _sm().__annotations.get(uuid, {})
	if data.is_empty():
		return
	
	var node: EditorStateMachineAnnotation = SCENE_ANNOTATION.instantiate()
	node.uuid = uuid
	node.text = data.get("text", "")
	node.position_offset = data.get("position", Vector2.ZERO)
	node.position_offset_changed.connect(_on_annotation_moved.bind(node), CONNECT_DEFERRED)
	add_child(node)


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
