extends Node

@export var music_slider: SliderSettingEntry
@export var sfx_slider: SliderSettingEntry
@export var output_device_dropdown: DropdownSettingEntry


func _ready() -> void:
	music_slider.slider_value = Config.audio.music_volume
	sfx_slider.slider_value = Config.audio.sfx_volume
	
	music_slider.set_toggle(Config.audio.music_on, false)
	sfx_slider.set_toggle(Config.audio.sfx_on, false)
	
	populate_output_devices()
	
	output_device_dropdown.selected_index = output_device_dropdown.options.find(Config.audio.output_device)
	# BUG This has to be selected later because an option cannot be immediately
	# selected after adding an item to a dropdown. 


func populate_output_devices() -> void:
	output_device_dropdown.options.clear()
	
	for audio_device: String in AudioServer.get_output_device_list():
		output_device_dropdown.options.append(audio_device)
	
	output_device_dropdown.populate_dropdown()



func _on_music_toggled(value: bool) -> void:
	Config.audio.music_on = value
	Config.apply()


func _on_music_value_changed(value: float) -> void:
	Config.audio.music_volume = value
	Config.apply()


func _on_sfx_toggled(value: bool) -> void:
	Config.audio.sfx_on = value
	Config.apply()


func _on_sfx_value_changed(value: float) -> void:
	Config.audio.sfx_volume = value
	Config.apply()


func _on_output_device_option_selected(index: int) -> void:
	Config.audio.output_device = output_device_dropdown.options[index]
	Config.apply()
