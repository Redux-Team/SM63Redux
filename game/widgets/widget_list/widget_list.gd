extends PropertyWidget

const MAX_ITEM_LENGTH: int = 32

@export var label: Label
@export var option_button: OptionButton

var _text_values: bool = false


func _ready() -> void:
	option_button.fit_to_longest_item = false
	option_button.clip_text = true
	option_button.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	option_button.item_selected.connect(_on_item_selected)


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	_text_values = widget_info.get("type") == TYPE_STRING
	option_button.clear()
	var next_id: int = 0
	for entry: String in String(widget_info.get("hint_string", "")).split(",", false):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() > 1:
			next_id = parts.get(1).to_int()
		var text: String = parts.get(0)
		option_button.add_item(text if text.length() <= MAX_ITEM_LENGTH else text.left(MAX_ITEM_LENGTH - 1) + "…", next_id)
		var index: int = option_button.item_count - 1
		option_button.set_item_metadata(index, text)
		option_button.set_item_tooltip(index, text)
		next_id += 1


func _value(widget_value: Variant) -> void:
	if not _text_values:
		option_button.select(option_button.get_item_index(int(widget_value)))
		return
	
	option_button.select(0)
	for index: int in option_button.item_count:
		if option_button.get_item_metadata(index) == str(widget_value):
			option_button.select(index)


func _on_item_selected(index: int) -> void:
	if _text_values:
		_commit(option_button.get_item_metadata(index))
	else:
		_commit(option_button.get_item_id(index))
