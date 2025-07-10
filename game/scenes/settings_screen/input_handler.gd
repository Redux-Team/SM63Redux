extends Node

const INPUT_SETTING_ENTRY = preload("uid://b4oq1mqltbkso")

@export var device_label: Label
@export var controls_vbox: VBoxContainer
@export var keyboard_vbox: VBoxContainer
@export var touchscreen_vbox: VBoxContainer


func _ready() -> void:
	Singleton.input_type_changed.connect(_update_input_menu)
	_update_input_menu(Singleton.current_input_device)


func _update_input_menu(device_type: Singleton.InputType) -> void:
	device_label.text = "Device Detected: %s" % Singleton.get_active_input_device()
	
	keyboard_vbox.hide()
	touchscreen_vbox.hide()
	
	match device_type:
		Singleton.InputType.KEYBOARD:
			keyboard_vbox.show()
		Singleton.InputType.TOUCHSCREEN:
			touchscreen_vbox.show()
