extends Node

const INPUT_SETTING_ENTRY = preload("uid://b4oq1mqltbkso")

@export var device_label: Label
@export var bindings_label: RichTextLabel
@export var controls_vbox: VBoxContainer
@export var input_vbox: VBoxContainer
@export var input_scroll_container: ScrollContainer
@export var touchscreen_vbox: VBoxContainer


func _ready() -> void:
	Singleton.input_type_changed.connect(_update_input_menu)
	_update_input_menu()
	
	var first_entry: bool = true
	
	for input: String in Config.get_control_scheme().get_inputs_string():
		var entry: InputSettingEntry = INPUT_SETTING_ENTRY.instantiate()
		entry.setting_name = input
		entry.input_events = ControlScheme.get_events(input)
		input_vbox.add_child(entry)
		
		if first_entry:
			entry.focus_entered.connect(func() -> void:
				input_scroll_container.scroll_vertical = 0
			)
			entry.visibility_changed.connect(func() -> void:
				if entry.visible and not get_viewport().gui_get_focus_owner():
					entry.interaction.grab_focus()
			)
			
			first_entry = false


func _update_input_menu() -> void:
	var device_type: Singleton.InputType = Singleton.current_input_device
	
	device_label.text = "Device Detected: %s" % Singleton.get_active_input_device()
	
	
	if device_type == Singleton.InputType.TOUCHSCREEN:
		input_vbox.hide()
		touchscreen_vbox.show()
	else:
		bindings_label.text = "Press %s to clear!" % ControlScheme.get_hint("_clear_setting")
		touchscreen_vbox.hide()
		input_vbox.show()


func _on_restore_defaults_pressed() -> void:
	Config.reset_control_scheme()
	SFX.play(SFX.UI_CONFIRM)
