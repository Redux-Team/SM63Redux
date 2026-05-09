@tool
class_name EditorStateMachineStateNode
extends GraphNode

const STATE_ICON = preload("uid://btg8b714itoxv")
const SLOT_TRANSITION_OUT: int = 0
const SLOT_TRANSITION_IN: int = 1
const SLOT_SUPERSTATE: int = 2
const COLOR_OUT: Color = Color(0.114, 0.620, 0.459)
const COLOR_IN: Color = Color(0.886, 0.294, 0.290)
const COLOR_SUPERSTATE: Color = Color(0.498, 0.467, 0.867)

@export var superstate_button: Button
@export var superstate_h_box: HBoxContainer
@export var empty_ss_label: Label

var editor: EditorStateMachineEditor
var uuid: String = ""
var superstate_uuid: String = ""
var alias_of: String = ""

var _script_button: Button
var _remove_script_button: Button


func _ready() -> void:
	if not editor:
		return
	
	_setup_titlebar()
	_setup_slots()
	_set_superstate(superstate_uuid)
	_update_script_button()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.double_click:
		_on_script_button_pressed()
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos: Vector2 = event.position
		var out_port_pos: Vector2 = get_output_port_position(0)
		var in_port_pos: Vector2 = get_input_port_position(0)
		if local_pos.distance_to(out_port_pos) < 12.0:
			_select_transitions_at_port(false)
			accept_event()
		elif local_pos.distance_to(in_port_pos) < 12.0:
			_select_transitions_at_port(true)
			accept_event()


func _select_transitions_at_port(is_input: bool) -> void:
	var graph: EditorStateMachineGraphEdit = get_parent() as EditorStateMachineGraphEdit
	if not graph:
		return
	
	var matches: Array[StateTransition] = []
	var match_tids: Array[StringName] = []
	for conn: Dictionary in graph.get_connection_list():
		if conn.from_port != 0 or conn.to_port != 0:
			continue
		var is_mine: bool = (is_input and conn.to_node == StringName(uuid)) or (not is_input and conn.from_node == StringName(uuid))
		if not is_mine:
			continue
		var logical_from: StringName = graph._resolve_uuid(StringName(conn.from_node))
		var logical_to: StringName = graph._resolve_uuid(StringName(conn.to_node))
		for tid: StringName in editor._current_sm.__transitions:
			var t: StateTransition = editor._current_sm.__transitions.get(tid) as StateTransition
			if not t:
				continue
			if t.__from_uuid == logical_from and t.__to_uuid == logical_to:
				matches.append(t)
				match_tids.append(tid)
				break
	
	if matches.is_empty():
		return
	if matches.size() == 1:
		graph._selected_transition_tid = match_tids[0]
		EditorInterface.inspect_object(matches[0])
		graph.connection_overlay.queue_redraw()
		return
	
	var current_idx: int = -1
	for i: int in match_tids.size():
		if match_tids[i] == graph._selected_transition_tid:
			current_idx = i
			break
	var next_idx: int = (current_idx + 1) % matches.size()
	graph._selected_transition_tid = match_tids[next_idx]
	EditorInterface.inspect_object(matches[next_idx])
	graph.connection_overlay.queue_redraw()


func _setup_titlebar() -> void:
	var hbox: HBoxContainer = get_titlebar_hbox()
	for child: Node in hbox.get_children():
		child.queue_free()
	
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = STATE_ICON
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(16.0, 16.0)
	
	var label: Label = Label.new()
	var state: State = _get_state()
	if not alias_of.is_empty():
		label.text = "(%s)" % state.name if state else name
		label.modulate = Color(1.0, 0.85, 0.1)
	else:
		label.text = state.name if state else name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	_script_button = Button.new()
	_script_button.custom_minimum_size = Vector2(16.0, 16.0)
	_script_button.pressed.connect(_on_script_button_pressed)
	
	_remove_script_button = Button.new()
	_remove_script_button.custom_minimum_size = Vector2(16.0, 16.0)
	_remove_script_button.icon = get_theme_icon("Remove", "EditorIcons")
	_remove_script_button.tooltip_text = "Remove Script"
	_remove_script_button.pressed.connect(_on_remove_script_button_pressed)
	_remove_script_button.hide()
	
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(icon_rect)
	hbox.add_child(label)
	hbox.add_child(_script_button)
	hbox.add_child(_remove_script_button)


func _update_script_button() -> void:
	if not _script_button:
		return
	var state: State = _get_state()
	if not state:
		return
	var s: Script = state.get_script() as Script
	var has_custom: bool = s != null and s != State
	_script_button.modulate = Color.DEEP_SKY_BLUE if has_custom else Color.WHITE
	_script_button.icon = get_theme_icon("Script", "EditorIcons") if has_custom else get_theme_icon("ScriptExtend", "EditorIcons")
	_script_button.tooltip_text = "Edit Script" if has_custom else "Attach Script"
	if _remove_script_button:
		_remove_script_button.visible = has_custom


func _on_remove_script_button_pressed() -> void:
	var state: State = _get_state()
	if not state:
		return
	var base_script: Script = load("uid://dyjrhpdveexsr") as Script
	if not base_script:
		return
	
	var preserved: Dictionary = {}
	for prop: Dictionary in state.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
			preserved[prop.name] = state.get(prop.name)
	
	state.set_script(base_script)
	
	for prop: Dictionary in state.get_property_list():
		if prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and prop.usage & PROPERTY_USAGE_STORAGE:
			if preserved.has(prop.name):
				state.set(prop.name, preserved[prop.name])
	
	_update_script_button()
	EditorInterface.inspect_object(state)


func _on_script_button_pressed() -> void:
	editor._open_or_create_state_script(_resolve_uuid())


func _resolve_uuid() -> String:
	return alias_of if not alias_of.is_empty() else uuid


func _on_node_selected() -> void:
	var state: State = _get_state()
	if state:
		EditorInterface.inspect_object(state)


func _setup_slots() -> void:
	while get_child_count() < 2:
		var spacer: Control = Control.new()
		spacer.custom_minimum_size = Vector2(0.0, 8.0)
		add_child(spacer)
	
	set_slot(0,
		true, 0, COLOR_IN,
		true, 0, COLOR_OUT)
	set_slot(1,
		alias_of.is_empty(), 0, COLOR_SUPERSTATE,
		false, 0, COLOR_SUPERSTATE)


func _get_state() -> State:
	if not alias_of.is_empty():
		return editor._current_sm.__states.get(alias_of, null)
	return editor._current_sm.__states.get(uuid, null)


func _get_superstate() -> State:
	var resolved: String = superstate_uuid
	var alias_data: Dictionary = editor._current_sm.__aliases.get(superstate_uuid, {})
	if not alias_data.is_empty():
		resolved = alias_data.get("original_uuid", superstate_uuid)
	return editor._current_sm.__states.get(resolved, null)


func _set_entry_port_enabled(enabled: bool) -> void:
	set_slot(1,
		alias_of.is_empty(), 0, COLOR_SUPERSTATE,
		enabled, 0, COLOR_SUPERSTATE)


func _set_superstate(new_uuid: String) -> void:
	var old_uuid: String = superstate_uuid
	superstate_uuid = new_uuid
	
	if alias_of.is_empty():
		var state: State = _get_state()
		if state:
			state.__editor_superstate_uuid = new_uuid
	
	var has_superstate: bool = not new_uuid.is_empty()
	_set_entry_port_enabled(has_superstate)
	
	if has_superstate:
		var superstate: State = _get_superstate()
		superstate_button.text = superstate.name if superstate else ""
		superstate_button.icon = STATE_ICON
		superstate_h_box.show()
		empty_ss_label.hide()
	else:
		superstate_h_box.hide()
		empty_ss_label.show()
	
	if old_uuid != new_uuid and is_inside_tree():
		var graph: EditorStateMachineGraphEdit = get_parent() as EditorStateMachineGraphEdit
		if graph:
			graph._propagate_superstate(uuid, old_uuid, new_uuid)
	
	size = Vector2.ZERO


func _propagate_superstate(source_uuid: String, old_superstate_uuid: String, new_superstate_uuid: String) -> void:
	for child: Node in get_children():
		var node: EditorStateMachineStateNode = child as EditorStateMachineStateNode
		if not node or node.uuid == source_uuid:
			continue
		if node.superstate_uuid == old_superstate_uuid:
			node._set_superstate(new_superstate_uuid)
