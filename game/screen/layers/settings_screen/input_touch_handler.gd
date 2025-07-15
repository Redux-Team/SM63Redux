extends Node


@export var preview: TouchScreen
@export var scale_slider: SliderSettingEntry
@export var opacity_slider: SliderSettingEntry
@export var sub_viewport: SubViewport
@export var device_label: Label
@export var expand_preview_button: Button
@export var expanded_h_box: HBoxContainer
@export var restore_defaults: Button


func _ready() -> void:
	scale_slider.slider_value = Config.input.touch_button_scale
	opacity_slider.slider_value = Config.input.touch_button_opacity
	
	if Config.input.touch_screen_scene:
		preview.free()
		preview = Config.input.touch_screen_scene.instantiate()
		preview.preview = true
		sub_viewport.add_child(preview)
	
	apply_modifiers()


func apply_modifiers() -> void:
	preview.apply_scale(Config.input.touch_button_scale)
	preview.apply_opacity(Config.input.touch_button_opacity)


func _on_touch_scale_value_changed(value: float) -> void:
	Config.input.touch_button_scale = value
	preview.apply_scale(value)


func _on_touch_opacity_value_changed(value: float) -> void:
	Config.input.touch_button_opacity = value
	preview.apply_opacity(value)


func _on_restore_defaults_pressed() -> void:
	preview.free()
	Config.input.touch_screen_scene = null
	
	preview = TouchScreen.new_instance()
	preview.apply_scale(1.2)
	preview.apply_opacity(0.6)
	
	scale_slider.slider_value = 1.2
	opacity_slider.slider_value = 60
	
	preview.preview = true
	
	sub_viewport.add_child(preview)
	
	apply_modifiers()


func _on_settings_screen_exit_request() -> void:
	Config.input.touch_screen_scene = preview.get_packed_scene()


func _on_expand_preview_pressed() -> void:
	scale_slider.hide()
	opacity_slider.hide()
	device_label.hide()
	expand_preview_button.hide()
	restore_defaults.hide()
	expanded_h_box.show()
	
	SFX.play(SFX.UI_CONFIRM)


func _on_minimize_preview_pressed() -> void:
	scale_slider.show()
	opacity_slider.show()
	device_label.show()
	restore_defaults.show()
	expand_preview_button.show()
	expanded_h_box.hide()
	
	SFX.play(SFX.UI_BACK)
