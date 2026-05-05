@tool
class_name EditorStateMachineGraphEdit
extends GraphEdit

enum MenuItem { NEW_STATE, NEW_ANNOTATION }

const SCENE_STATE_NODE = preload("uid://lw2tqa550ufn")
const SCENE_ANNOTATION = preload("uid://cxlnpbgvix7ms")

const MENU_ITEMS: Dictionary[String, MenuItem] = {
	"+ State": MenuItem.NEW_STATE,
	"+ Annotation": MenuItem.NEW_ANNOTATION,
}

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


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT:
		add_node_menu.position = event.global_position
		add_node_menu.popup()
		_popup_pos = (event.position + scroll_offset) / zoom
	
	_sm().__last_editor_position = scroll_offset
	_sm().__last_editor_zoom = zoom


func _sm() -> StateMachine:
	return state_machine_editor._current_sm


func _on_delete_nodes_request(node_names: Array[StringName]) -> void:
	for node_name: StringName in node_names:
		var node: Node = find_child(node_name, false, false)
		if not node:
			continue
		
		if node is EditorStateMachineStateNode:
			_remove_state(node.uuid)
			_clear_superstate_references(node.uuid)
		elif node is EditorStateMachineAnnotation:
			_remove_annotation(node.uuid)
		
		node.queue_free()


func _clear_superstate_references(deleted_uuid: String) -> void:
	for child: Node in get_children():
		if child is EditorStateMachineStateNode and child.superstate_uuid == deleted_uuid:
			child._set_superstate("")


func _on_add_node_menu_id_pressed(id: int) -> void:
	match id:
		MenuItem.NEW_STATE:
			add_state_dialog.popup_centered()
		MenuItem.NEW_ANNOTATION:
			add_annotation_dialog.popup_centered()


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
		if state._editor_name == label:
			return true
	return false


func _add_state(label: String, pos: Vector2) -> void:
	var uuid: String = Packer.generate_uuid()
	var state: State = State.new()
	state._editor_name = label
	state._editor_position = pos
	state._editor_uuid = uuid
	
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
	node.uuid = uuid
	node.title = state._editor_name
	node.position_offset = state._editor_position
	node.superstate_uuid = state._editor_superstate_uuid
	node.editor = owner
	node.position_offset_changed.connect(_on_state_node_moved.bind(node), CONNECT_DEFERRED)
	add_child(node)


func _add_annotation(text: String, pos: Vector2) -> void:
	var uuid: String = Packer.generate_uuid()
	_sm().__annotations[uuid] = { "text": text, "position": pos }
	_spawn_annotation_node(uuid)


func _remove_annotation(uuid: String) -> void:
	_sm().__annotations.erase(uuid)


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
	var state: State = _sm().__states.get(node.uuid)
	if state:
		state._editor_position = node.position_offset


func _on_annotation_moved(node: EditorStateMachineAnnotation) -> void:
	var data: Dictionary = _sm().__annotations.get(node.uuid, {})
	data["position"] = node.position_offset
	_sm().__annotations[node.uuid] = data
