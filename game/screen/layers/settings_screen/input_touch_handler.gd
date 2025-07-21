extends Node

const TOUCH_SCREEN: PackedScene = preload("uid://l87i6yic73um")


@export var preview: TouchScreen
@export var scale_slider: SliderSettingEntry
@export var opacity_slider: SliderSettingEntry
@export var sub_viewport: SubViewport
@export var device_label: Label
@export var expand_preview_button: Button
@export var expanded_h_box: HBoxContainer
@export var restore_defaults_button: Button


func _ready() -> void:
	scale_slider.slider_value = Config.input.touch_button_scale
	opacity_slider.slider_value = Config.input.touch_button_opacity
	
	if not Config.input.touch_button_positions:
		restore_defaults()
	
	preview.assign_positions(Config.input.touch_button_positions)
	
	apply_modifiers()


func apply_modifiers() -> void:
	preview.apply_scale(Config.input.touch_button_scale)
	preview.apply_opacity(Config.input.touch_button_opacity)


func restore_defaults() -> void:
	preview.assign_positions(TOUCH_SCREEN.instantiate().get_positions())
	scale_slider.slider_value = 1.2
	opacity_slider.slider_value = 60
	apply_modifiers()


func _on_touch_scale_value_changed(value: float) -> void:
	Config.input.touch_button_scale = value
	preview.apply_scale(value)


func _on_touch_opacity_value_changed(value: float) -> void:
	Config.input.touch_button_opacity = value
	preview.apply_opacity(value)


func _on_restore_defaults_pressed() -> void:
	restore_defaults()


func _on_settings_screen_exit_request() -> void:
	Config.input.touch_button_positions = preview.get_positions()


func _on_expand_preview_pressed() -> void:
	scale_slider.hide()
	opacity_slider.hide()
	device_label.hide()
	expand_preview_button.hide()
	restore_defaults_button.hide()
	expanded_h_box.show()
	
	SFX.play(SFX.UI_CONFIRM)


func _on_minimize_preview_pressed() -> void:
	scale_slider.show()
	opacity_slider.show()
	device_label.show()
	restore_defaults_button.show()
	expand_preview_button.show()
	expanded_h_box.hide()
	
	SFX.play(SFX.UI_BACK)
