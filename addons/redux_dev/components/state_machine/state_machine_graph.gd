@tool
class_name EditorStateMachineGraph
extends GraphEdit


var _pending_spawn_position: Vector2 = Vector2.ZERO
var _target_node: Node = null
var _add_node_menu: PopupMenu
var _name_dialog: AcceptDialog
var _name_input: LineEdit
var _resource: StateMachineResource = null


func _ready() -> void:
	if not _is_plugin_instance():
		return
	
	_build_add_node_menu()
	_build_name_dialog()


func _build_add_node_menu() -> void:
	_add_node_menu = PopupMenu.new()
	_add_node_menu.add_item("Add State", 0)
	_add_node_menu.id_pressed.connect(_on_add_node_menu_id_pressed)
	add_child(_add_node_menu)


func _build_name_dialog() -> void:
	_name_dialog = AcceptDialog.new()
	_name_dialog.title = "Name State"
	_name_dialog.ok_button_text = "Create"
	_name_dialog.confirmed.connect(_on_name_dialog_confirmed)
	
	_name_input = LineEdit.new()
	_name_input.placeholder_text = "State name..."
	_name_input.custom_minimum_size = Vector2(220.0, 0.0)
	_name_input.text_submitted.connect(_on_name_input_submitted)
	
	_name_dialog.add_child(_name_input)
	add_child(_name_dialog)


func set_target_node(node: Node) -> void:
	_target_node = node


func _gui_input(event: InputEvent) -> void:
	if not _is_plugin_instance():
		return
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_RIGHT \
			and event.is_pressed():
		_pending_spawn_position = (event.position + scroll_offset) / zoom
		_add_node_menu.popup(Rect2(event.global_position, Vector2.ZERO))
		accept_event()


func _on_add_node_menu_id_pressed(id: int) -> void:
	if id == 0:
		_name_input.clear()
		_name_dialog.popup_centered()
		_name_input.grab_focus()


func _on_name_input_submitted(_text: String) -> void:
	_name_dialog.hide()
	_spawn_state_node(_name_input.text.strip_edges())


func _on_name_dialog_confirmed() -> void:
	_spawn_state_node(_name_input.text.strip_edges())


func _spawn_state_node(state_name: String) -> void:
	if state_name.is_empty():
		return
	
	var graph_node: EditorStateMachineGraphNode = EditorStateMachineGraphNode.new()
	graph_node.title = state_name
	graph_node.state_name = state_name
	graph_node.position_offset = _pending_spawn_position
	add_child(graph_node)
	graph_node.owner = owner
	graph_node.dragged.connect(_on_graph_node_dragged)
	graph_node.script_changed_in_editor.connect(_save_resource)
	_save_resource()


func _is_plugin_instance() -> bool:
	return owner is EditorStateMachineEditor


func load_resource(resource: StateMachineResource) -> void:
	_resource = resource
	_clear_graph()
	call_deferred(&"_load_states")


func _load_states() -> void:
	for state_data: Dictionary in _resource.states:
		var node: EditorStateMachineGraphNode = EditorStateMachineGraphNode.new()
		node.state_name = state_data.get("name", "State")
		node.position_offset = Vector2(
			state_data.get("position_x", 0.0),
			state_data.get("position_y", 0.0)
		)
		add_child(node)
		node.owner = owner
		node.dragged.connect(_on_graph_node_dragged)
		node.script_changed_in_editor.connect(_save_resource)
		var script_path: String = state_data.get("script_path", "")
		if not script_path.is_empty() and ResourceLoader.exists(script_path):
			node.apply_script_from_path(script_path)


func _on_graph_node_dragged(_from: Vector2, _to: Vector2) -> void:
	_save_resource()


func _clear_graph() -> void:
	for child: Node in get_children():
		if child is EditorStateMachineGraphNode:
			child.free()


func _save_resource() -> void:
	if _resource == null:
		return
	
	var states: Array[Dictionary] = []
	for child: Node in get_children():
		if not child is EditorStateMachineGraphNode:
			continue
		var graph_node: EditorStateMachineGraphNode = child as EditorStateMachineGraphNode
		var entry: Dictionary = {
			"name": graph_node.state_name,
			"position_x": graph_node.position_offset.x,
			"position_y": graph_node.position_offset.y,
			"script_path": graph_node.get_script_path(),
		}
		states.append(entry)
	
	_resource.states = states
	ResourceSaver.save(_resource)
