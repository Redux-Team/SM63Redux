class_name SettingEntry
extends Node

signal setting_name_changed(value: StringName)

@export var setting_name: StringName:
	set(sn):
		setting_name = sn
		setting_name_changed.emit(sn)


func _on_setting_name_changed(value: StringName) -> void:
	pass
