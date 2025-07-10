extends Node


@export var preview: TouchScreenPreview
@export var scale_slider: SliderSettingEntry
@export var opacity_slider: SliderSettingEntry


func _ready() -> void:
	scale_slider.slider_value = Config.input.touch_button_scale
	opacity_slider.slider_value = Config.input.touch_button_opacity
	
	preview.apply_scale(Config.input.touch_button_scale)
	preview.apply_opacity(Config.input.touch_button_opacity)


func _on_touch_scale_value_changed(value: float) -> void:
	Config.input.touch_button_scale = value
	preview.apply_scale(value)


func _on_touch_opacity_value_changed(value: float) -> void:
	Config.input.touch_button_opacity = value
	preview.apply_opacity(value)
