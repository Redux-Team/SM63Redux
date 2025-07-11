@tool
class_name InputSettingEntry
extends SettingEntry

const CONTROLLER_ICONS = preload("uid://b5k5j0heehdeo")

@export var input_events: Array[InputEvent]

@export_group("Internal")
@export var input_name_label: Label
@export var input_events_label: RichTextLabel

var interaction_hovering: bool = false
var interaction_focused: bool = false
var interaction_pressed: bool = false

var listening_for_input: bool = false


func _ready() -> void:
	input_name_label.text = setting_name
	Singleton.input_type_changed.connect(_update_inputs)
	_update_inputs(Singleton.current_input_device)


func _update_inputs(type: Singleton.InputType) -> void:
	input_events_label.text = ""
	
	var events: PackedStringArray = []
	
	for event: InputEvent in input_events:
		
		if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and type == Singleton.InputType.CONTROLLER:
			events.append("[img=25px]%s[/img]" % CONTROLLER_ICONS.from_event(event).resource_path)
		
		elif event is InputEventKey and type == Singleton.InputType.KEYBOARD:
			events.append(event.as_text())
	
	var seperator: String = " " if type == Singleton.InputType.CONTROLLER else ", "
	
	input_events_label.text = seperator.join(events)


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		return
	
	if event is InputEventJoypadMotion:
		if abs(event.axis_value) < 0.5:
			return
	
	if listening_for_input:
		for input_event: InputEvent in input_events:
			if event.is_match(input_event, false):
				listening_for_input = false
				SFX.play(SFX.UI_BACK)
				accept_event()
				_update_inputs(Singleton.current_input_device)
				return
		
		input_events.append(event)
		_update_inputs(Singleton.current_input_device)
		accept_event()
		SFX.play(SFX.UI_CONFIRM)
		listening_for_input = false


func _update_text_color() -> void:
	input_name_label.add_theme_color_override(&"font_color", Color.WHITE)
	
	if interaction_hovering or interaction_focused:
		input_name_label.add_theme_color_override(&"font_color", Color.YELLOW)
	if interaction_pressed:
		input_name_label.add_theme_color_override(&"font_color", Color.AQUA)



func _on_interaction_focus_entered() -> void:
	interaction_focused = true
	_update_text_color()


func _on_interaction_focus_exited() -> void:
	interaction_focused = false
	listening_for_input = false
	_update_inputs(Singleton.current_input_device)
	_update_text_color()


func _on_interaction_button_down() -> void:
	interaction_pressed = true
	_update_text_color()


func _on_interaction_button_up() -> void:
	interaction_pressed = false
	_update_text_color()


func _on_interaction_mouse_entered() -> void:
	interaction_hovering = true
	_update_text_color()


func _on_interaction_mouse_exited() -> void:
	interaction_hovering = false
	_update_text_color()


func _on_interaction_pressed() -> void:
	if not listening_for_input:
		SFX.play(SFX.UI_NEXT)
		listening_for_input = true
		input_events_label.text += " [...] "
