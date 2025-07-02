extends Node

@export var music_slider: HSlider
@export var sfx_slider: HSlider


func _on_music_toggle_value_changed(value: bool) -> void:
	AudioServer.set_bus_mute(1, not value)
	music_slider.modulate = Color.WHITE if value else Color.DIM_GRAY
	music_slider.mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE


func _on_music_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(1, remap(value, 0, 100, -60, 20))


func _on_sfx_toggle_value_changed(value: bool) -> void:
	AudioServer.set_bus_mute(2, not value)
	sfx_slider.modulate = Color.WHITE if value else Color.DIM_GRAY
	sfx_slider.mouse_filter = Control.MOUSE_FILTER_PASS if value else Control.MOUSE_FILTER_IGNORE


func _on_sfx_slider_value_changed(value: float) -> void:
	AudioServer.set_bus_volume_db(2, remap(value, 0, 100, -60, 20))


func _on_sfx_slider_drag_ended(_value_changed: bool) -> void:
	SFX.play(SFX.UI_NEXT)
