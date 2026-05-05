@tool
class_name EditorStateMachineStateNode
extends GraphNode

const STATE_ICON = preload("uid://btg8b714itoxv")

const SLOT_TRANSITION_OUT := 0
const SLOT_TRANSITION_IN := 1
const SLOT_SUPERSTATE := 2

const COLOR_OUT := Color(0.114, 0.620, 0.459)
const COLOR_IN := Color(0.886, 0.294, 0.290)
const COLOR_SUPERSTATE := Color(0.498, 0.467, 0.867)

@export var superstate_button: Button
@export var superstate_h_box: HBoxContainer
@export var empty_ss_label: Label

var editor: EditorStateMachineEditor
var uuid: String = ""
var superstate_uuid: String = ""


func _ready() -> void:
	if not editor:
		return
	
	_setup_titlebar()
	_setup_slots()
	_set_superstate(superstate_uuid)


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
	label.text = state.name if state else name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(icon_rect)
	hbox.add_child(label)


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
		true, 0, COLOR_SUPERSTATE,
		false, 0, COLOR_SUPERSTATE)


func _get_state() -> State:
	return editor._current_sm.__states.get(uuid, null)


func _get_superstate() -> State:
	return editor._current_sm.__states.get(superstate_uuid, null)


func _set_entry_port_enabled(enabled: bool) -> void:
	set_slot(1,
		true, 0, COLOR_SUPERSTATE,
		enabled, 0, COLOR_SUPERSTATE)


func _set_superstate(new_uuid: String) -> void:
	superstate_uuid = new_uuid
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
	
	size = Vector2.ZERO
