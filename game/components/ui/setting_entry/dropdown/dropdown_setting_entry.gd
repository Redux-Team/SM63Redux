@tool
class_name DropdownSettingEntry
extends SettingEntry

signal option_selected(index: int)

@export var options: Array[String]
@export var selected_index: int:
	set(si):
		selected_index = wrapi(si, -1, options.size())
		dropdown.select(selected_index)

@export_group("Internal")
@export var label: Label
@export var dropdown: OptionButton


func _ready() -> void:
	label.text = setting_name
	setting_name_changed.connect(_on_setting_name_changed)
	
	dropdown.clear()
	for option: String in options:
		dropdown.add_item(option)


func _on_setting_name_changed(value: StringName) -> void:
	label.text = value


func _on_dropdown_item_selected(index: int) -> void:
	selected_index = index
	option_selected.emit(index)
