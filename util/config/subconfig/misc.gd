class_name MiscConfig
extends Subconfig


@export var show_timer: bool = false
@export var enforce_touch_display: bool = false
@export var disable_camera_limiting: bool = false
@export var language: StringName = &"English [en]"


func apply() -> void:
	if Singleton:
		Singleton.input_type_changed.emit()
