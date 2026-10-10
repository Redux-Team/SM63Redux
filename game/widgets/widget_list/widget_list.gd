extends PropertyWidget

@export var label: Label
@export var option_button: OptionButton


func _ready() -> void:
	option_button.item_selected.connect(_on_item_selected)


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	option_button.clear()
	var next_id: int = 0
	for entry: String in String(widget_info.get("hint_string", "")).split(",", false):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() > 1:
			next_id = parts.get(1).to_int()
		option_button.add_item(parts.get(0), next_id)
		next_id += 1


func _value(widget_value: Variant) -> void:
	option_button.select(option_button.get_item_index(int(widget_value)))


func _on_item_selected(index: int) -> void:
	_commit(option_button.get_item_id(index))
