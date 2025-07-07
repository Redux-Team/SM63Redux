extends Node

@export var music_slider: SliderSettingEntry
@export var sfx_slider: SliderSettingEntry


func _ready() -> void:
	music_slider.slider_value = Config.audio.music_volume
	sfx_slider.slider_value = Config.audio.sfx_volume
	
	music_slider.set_toggle(Config.audio.music_on)
	sfx_slider.set_toggle(Config.audio.sfx_on)


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
