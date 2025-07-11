extends Node

const INPUT_SETTING_ENTRY = preload("uid://b4oq1mqltbkso")
const DEFAULT_CONTROLSCHEME = preload("uid://wymwegktk0cr")

@export var device_label: Label
@export var controls_vbox: VBoxContainer
@export var input_vbox: VBoxContainer
@export var touchscreen_vbox: VBoxContainer


func _ready() -> void:
	Singleton.input_type_changed.connect(_update_input_menu)
	_update_input_menu(Singleton.current_input_device)
	
	for input: String in DEFAULT_CONTROLSCHEME.get_inputs_string():
		var entry: InputSettingEntry = INPUT_SETTING_ENTRY.instantiate()
		entry.setting_name = input.capitalize()
		entry.input_events = DEFAULT_CONTROLSCHEME.get(input)
		input_vbox.add_child(entry)


func _update_input_menu(device_type: Singleton.InputType) -> void:
	device_label.text = "Device Detected: %s" % Singleton.get_active_input_device()
	
	input_vbox.hide()
	touchscreen_vbox.hide()
	
	if device_type == Singleton.InputType.TOUCHSCREEN:
		touchscreen_vbox.show()
	else:
		input_vbox.show()
