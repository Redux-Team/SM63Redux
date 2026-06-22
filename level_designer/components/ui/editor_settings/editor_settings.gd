class_name LDEditorSettings
extends MarginContainer

## Editor preferences panel. Currently exposes the viewport camera (WASD) pan speed, backed by
## the global LDEditorConfig. Surfaced as a window via LDUIWindowHandler.


@export var pan_speed_slider: HSlider
@export var pan_speed_value: Label


func _ready() -> void:
	pan_speed_slider.min_value = LDEditorConfig.PAN_SPEED_MIN
	pan_speed_slider.max_value = LDEditorConfig.PAN_SPEED_MAX
	pan_speed_slider.step = 0.5
	pan_speed_slider.value_changed.connect(_on_pan_speed_changed)
	_sync()


func _on_show() -> void:
	_sync()


func _sync() -> void:
	var speed: float = LDEditorConfig.get_pan_speed()
	pan_speed_slider.set_value_no_signal(speed)
	_update_label(speed)


func _on_pan_speed_changed(value: float) -> void:
	LDEditorConfig.set_pan_speed(value)
	_update_label(value)


func _update_label(value: float) -> void:
	pan_speed_value.text = "%.1f" % value
