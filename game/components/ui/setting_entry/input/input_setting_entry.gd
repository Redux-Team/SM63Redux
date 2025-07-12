@tool
class_name InputSettingEntry
extends SettingEntry

@export var input_events: Array[InputEvent]

@export_group("Internal")
@export var input_name_label: Label
@export var input_events_label: RichTextLabel
@export var interaction: Button

var interaction_hovering: bool = false
var interaction_focused: bool = false
var interaction_pressed: bool = false
var listening_for_input: bool = false


func _ready() -> void:
	input_name_label.text = setting_name.capitalize()
	if not Engine.is_editor_hint():
		Singleton.input_type_changed.connect(_update_inputs)
	_update_inputs()


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		return
	
	if _should_ignore_joypad_motion(event):
		return
	
	if _handle_clear_input_shortcut(event):
		return
	
	if listening_for_input:
		_handle_input_listening(event)


func _update_inputs(type: Singleton.InputType = Singleton.current_input_device) -> void:
	input_events_label.text = ""
	
	var events: PackedStringArray = []
	
	for event: InputEvent in input_events:
		var event_text: String = _get_event_display_text(event, type)
		if event_text != "":
			events.append(event_text)
	
	var separator: String = " " if type == Singleton.InputType.CONTROLLER else ", "
	input_events_label.text = separator.join(events)


func _update_text_color() -> void:
	var color: Color = Color.WHITE
	
	if interaction_pressed:
		color = Color.AQUA
	elif interaction_hovering or interaction_focused:
		color = Color.YELLOW
	
	input_name_label.add_theme_color_override(&"font_color", color)


func _clear_inputs() -> void:
	input_events = input_events.filter(_should_keep_input_event)
	_update_inputs()


func _on_interaction_focus_entered() -> void:
	interaction_focused = true
	focus_entered.emit()
	_update_text_color()


func _on_interaction_focus_exited() -> void:
	interaction_focused = false
	listening_for_input = false
	_update_inputs()
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


func _on_interaction_gui_input(event: InputEvent) -> void:
	if listening_for_input:
		return
	
	if _is_right_mouse_release(event):
		SFX.play(SFX.UI_BACK)
		_clear_inputs()


func _should_ignore_joypad_motion(event: InputEvent) -> bool:
	if event is InputEventJoypadMotion:
		return abs(event.axis_value) < 0.5
	return false


func _handle_clear_input_shortcut(event: InputEvent) -> bool:
	if event is InputEventJoypadButton:
		var joypad_event: InputEventJoypadButton = event as InputEventJoypadButton
		if joypad_event.button_index == 8 and joypad_event.pressed and interaction_focused and not listening_for_input:
			SFX.play(SFX.UI_BACK)
			_clear_inputs()
			return true
	return false


func _handle_input_listening(event: InputEvent) -> void:
	for input_event: InputEvent in input_events:
		if event.is_match(input_event, false):
			listening_for_input = false
			SFX.play(SFX.UI_BACK)
			accept_event()
			_update_inputs()
			return
	
	input_events.append(event)
	
	Singleton.current_control_scheme.set(setting_name, input_events)
	Singleton.current_control_scheme.assign_to_map()
	Singleton.input_type_changed.emit(Singleton.current_input_device)
	
	_update_inputs()
	accept_event()
	SFX.play(SFX.UI_CONFIRM)
	listening_for_input = false


func _get_event_display_text(event: InputEvent, type: Singleton.InputType) -> String:
	var is_controller_event: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
	var is_keyboard_event: bool = event is InputEventKey
	
	if is_controller_event and type == Singleton.InputType.CONTROLLER:
		return "[img=25px]%s[/img]" % Singleton.CONTROLLER_ICONS.from_event(event).resource_path
	elif is_keyboard_event and type == Singleton.InputType.KEYBOARD:
		var key_event: InputEventKey = event as InputEventKey
		return key_event.as_text()
	
	return ""


func _should_keep_input_event(input_event: InputEvent) -> bool:
	var current_device: Singleton.InputType = Singleton.current_input_device
	var is_controller_event: bool = input_event is InputEventJoypadButton or input_event is InputEventJoypadMotion
	var is_keyboard_event: bool = input_event is InputEventKey
	
	if current_device == Singleton.InputType.CONTROLLER and is_controller_event:
		return false
	
	if current_device == Singleton.InputType.KEYBOARD and is_keyboard_event:
		return false
	
	return true


func _is_right_mouse_release(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton
		return mouse_event.button_index == 2 and not mouse_event.pressed
	return false
