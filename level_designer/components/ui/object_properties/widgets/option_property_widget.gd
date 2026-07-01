class_name LDOptionWidget
extends LDPropertyWidget


@export var property_label: Label
@export var option_button: OptionButton
@export var reset_button: Button


func _ready() -> void:
	option_button.item_selected.connect(func(idx: int) -> void:
		var value: String = "" if idx == 0 else option_button.get_item_text(idx)
		_update_reset_button(value)
		value_changed.emit(_key, value)
	)
	reset_button.pressed.connect(func() -> void:
		value_changed.emit(_key, _default_value)
	)


func set_options(options: PackedStringArray) -> void:
	if not option_button:
		return
	option_button.clear()
	for option: String in options:
		option_button.add_item(option)


func _set_label(text: String) -> void:
	if property_label:
		property_label.text = text


func _set_value(value: Variant) -> void:
	if not option_button or option_button.item_count == 0:
		return
	var target: String = str(value) if value != null else ""
	var selected: int = 0
	if not target.is_empty():
		for i: int in option_button.item_count:
			if option_button.get_item_text(i) == target:
				selected = i
				break
	option_button.select(selected)
	_update_reset_button(target)


func _update_reset_button(current_value: Variant) -> void:
	if not reset_button:
		return
	reset_button.visible = str(current_value) != str(_default_value)


func _on_property_applied(value: Variant) -> void:
	_set_value(value)
