extends Node

const LANGUAGE_OPTIONS: Array[String] = [
	"en", # English
]


@export var show_timer_toggle: BooleanSettingEntry
@export var enforce_touch_toggle: BooleanSettingEntry
@export var camera_limit_toggle: BooleanSettingEntry


func _ready() -> void:
	show_timer_toggle.value = Config.misc.show_timer
	enforce_touch_toggle.value = Config.misc.enforce_touch_controls
	camera_limit_toggle.value = Config.misc.disable_camera_limiting


func _on_show_timer_value_changed(value: bool) -> void:
	Config.misc.show_timer = value


func _on_enforce_touch_value_changed(value: bool) -> void:
	Config.misc.enforce_touch_controls = value


func _on_camera_limit_value_changed(value: bool) -> void:
	Config.misc.disable_camera_limiting = value


func _on_language_option_button_item_selected(index: int) -> void:
	Config.misc.language = LANGUAGE_OPTIONS[index]
