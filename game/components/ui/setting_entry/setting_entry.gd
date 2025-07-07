class_name SettingEntry
extends Node

signal setting_name_changed(value: StringName)
#signal setting_group_changed(value: StringName)

@export var setting_name: StringName:
	set(sn):
		setting_name = sn
		setting_name_changed.emit(sn)
@export var setting_group: StringName:
	set(sg):
		setting_group = sg
		#setting_group_changed.emit(sg)
