@tool
class_name EditorStateMachineStateNode
extends GraphNode

const STATE_ICON = preload("uid://btg8b714itoxv")

@export var superstate_button: Button
@export var superstate_delete_button: Button

var editor: EditorStateMachineEditor
var uuid: String = ""
var superstate_uuid: String = ""


func _ready() -> void:
	_setup_titlebar()
	
	var remove_icon: Texture2D = EditorInterface.get_editor_theme().get_icon(&"Remove", &"EditorIcons")
	superstate_delete_button.icon = remove_icon
	
	_refresh_superstate_button()


func _setup_titlebar() -> void:
	var hbox: HBoxContainer = get_titlebar_hbox()
	for child: Node in hbox.get_children():
		child.queue_free()
	
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = STATE_ICON
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(16.0, 16.0)
	
	var label: Label = Label.new()
	label.text = _get_state().name
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(icon_rect)
	hbox.add_child(label)


func _refresh_superstate_button() -> void:
	var superstate: State = _get_superstate()
	var has_superstate: bool = superstate != null
	superstate_button.text = superstate.name if has_superstate else "<null>"
	superstate_button.icon = STATE_ICON if has_superstate else null
	superstate_delete_button.visible = has_superstate


func _get_state() -> State:
	return editor._current_sm.__states.get(uuid, null)


func _get_superstate() -> State:
	return editor._current_sm.__states.get(superstate_uuid, null)


func _set_superstate(new_uuid: String) -> void:
	superstate_uuid = new_uuid
	var state: State = _get_state()
	if state:
		state._editor_superstate_uuid = new_uuid
	_refresh_superstate_button()
	size = Vector2.ZERO


func _on_superstate_button_pressed() -> void:
	EditorInterface.popup_node_selector(func(node_path: NodePath) -> void:
		if node_path.is_empty():
			return
		var picked: State = editor._current_sm.owner.get_node(node_path)
		if picked._editor_uuid == uuid:
			EditorInterface.get_editor_toaster().push_toast("Cannot set a state as its own superstate!")
			return
		_set_superstate(picked._editor_uuid)
	, [&"State"])


func _on_superstate_delete_button_pressed() -> void:
	_set_superstate("")
