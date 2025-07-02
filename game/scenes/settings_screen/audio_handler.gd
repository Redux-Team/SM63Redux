extends Node

@export var music_toggle: BooleanSettingEntry
@export var music_slider: HSlider
@export var music_percent_label: Label

@export var sfx_toggle: BooleanSettingEntry
@export var sfx_slider: HSlider
@export var sfx_percent_label: Label


func _ready() -> void:
	music_toggle.value = Config.audio.music_on
	music_slider.value = Config.audio.music_volume
	
	sfx_toggle.value = Config.audio.sfx_on
	sfx_slider.value = Config.audio.sfx_volume
	
	_update_sliders()
	_update_percentages()


func _update_sliders() -> void:
	music_slider.modulate = Color.WHITE if Config.audio.music_on else Color.DIM_GRAY
	music_slider.mouse_filter = Control.MOUSE_FILTER_PASS if Config.audio.music_on else Control.MOUSE_FILTER_IGNORE
	
	sfx_slider.modulate = Color.WHITE if Config.audio.sfx_on else Color.DIM_GRAY
	sfx_slider.mouse_filter = Control.MOUSE_FILTER_PASS if Config.audio.sfx_on else Control.MOUSE_FILTER_IGNORE


func _update_percentages() -> void:
	music_percent_label.text = "%s%%" % int(Config.audio.music_volume)
	sfx_percent_label.text = "%s%%" % int(Config.audio.sfx_volume)


func _on_music_toggle_value_changed(value: bool) -> void:
	Config.audio.music_on = value
	Config.apply()
	_update_sliders()


func _on_music_slider_value_changed(value: float) -> void:
	Config.audio.music_volume = value
	Config.apply()
	_update_percentages()


func _on_sfx_toggle_value_changed(value: bool) -> void:
	Config.audio.sfx_on = value
	Config.apply()
	_update_sliders()


func _on_sfx_slider_value_changed(value: float) -> void:
	Config.audio.sfx_volume = value
	Config.apply()
	_update_percentages()


func _on_sfx_slider_drag_ended(_value_changed: bool) -> void:
	SFX.play(SFX.UI_NEXT)
