@tool
class_name DropdownSettingEntry
extends SettingEntry

signal option_selected(index: int)

@export var options: Array[String]
@export var selected_index: int:
	set(si):
		selected_index = wrapi(si, -1, options.size())
		if selected_index > 0 and selected_index < dropdown.get_popup().item_count:
			dropdown.select(selected_index)
@export var silent: bool = false

@export_group("Internal")
@export var label: Label
@export var dropdown: OptionButton


func _ready() -> void:
	label.text = setting_name
	setting_name_changed.connect(_on_setting_name_changed)
	populate_dropdown()


func populate_dropdown() -> void:
	dropdown.clear()
	for option: String in options:
		dropdown.add_item(option)


func _on_setting_name_changed(value: StringName) -> void:
	label.text = value


func _on_dropdown_item_selected(index: int) -> void:
	selected_index = index
	
	if not silent:
		SFX.play(SFX.UI_CONFIRM)
	
	option_selected.emit(index)


# HACK this should fix invalid assignments on initialization
func _on_visibility_changed() -> void:
	selected_index = selected_index
