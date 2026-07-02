@tool
class_name EditorStateMachineStateNode
extends GraphNode

const STATE_ICON = preload("uid://btg8b714itoxv")
const COLOR_OUT: Color = Color(0.114, 0.620, 0.459)
const COLOR_IN: Color = Color(0.886, 0.294, 0.290)
const COLOR_SUPERSTATE: Color = Color(0.498, 0.467, 0.867)

@export var superstate_button: Button
@export var superstate_h_box: HBoxContainer
@export var empty_ss_label: Label

var editor: EditorStateMachineEditor
var state: State

var _script_button: Button
var _name_label: Label


func _ready() -> void:
	if not is_instance_valid(state):
		return
	_setup_titlebar()
	_setup_body()
	_setup_slots()
	_update_superstate_display()
	_update_script_button()


func _setup_titlebar() -> void:
	var hbox: HBoxContainer = get_titlebar_hbox()
	for child: Node in hbox.get_children():
		child.queue_free()
	var icon_rect: TextureRect = TextureRect.new()
	icon_rect.texture = STATE_ICON
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.custom_minimum_size = Vector2(16.0, 16.0)
	_script_button = Button.new()
	_script_button.custom_minimum_size = Vector2(16.0, 16.0)
	_script_button.pressed.connect(_on_script_button_pressed)
	hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	hbox.add_child(icon_rect)
	hbox.add_child(_script_button)


func _setup_body() -> void:
	_name_label = get_node_or_null(^"Control") as Label
	if _name_label:
		_name_label.text = String(state.name)


func _setup_slots() -> void:
	set_slot(0, true, 0, COLOR_IN, true, 0, COLOR_OUT)
	set_slot(1, true, 1, COLOR_SUPERSTATE, true, 1, COLOR_SUPERSTATE)


func _update_superstate_display() -> void:
	var parent: Node = state.get_parent()
	if parent is State:
		superstate_button.text = String((parent as State).name)
		superstate_button.icon = STATE_ICON
	else:
		superstate_button.text = "<none>"
		superstate_button.icon = null
	superstate_h_box.show()
	empty_ss_label.hide()


func _update_script_button() -> void:
	if not _script_button:
		return
	var s: Script = state.get_script() as Script
	var has_custom: bool = s != null and s != State
	_script_button.visible = has_custom
	if has_custom:
		_script_button.icon = get_theme_icon("Script", "EditorIcons")
		_script_button.tooltip_text = "Edit Script"


func _on_script_button_pressed() -> void:
	if not is_instance_valid(state):
		return
	var s: Script = state.get_script() as Script
	if s and s != State:
		EditorInterface.edit_script(s)
		EditorInterface.set_main_screen_editor("Script")


func _on_node_selected() -> void:
	if is_instance_valid(state):
		EditorInterface.inspect_object(state)
