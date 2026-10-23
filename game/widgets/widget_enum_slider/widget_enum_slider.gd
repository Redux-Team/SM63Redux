extends PropertyWidget

@export var label: Label
@export var slider: UISlider
@export var value_label: Label

var _names: PackedStringArray = []
var _ids: PackedInt32Array = []


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	_names.clear()
	_ids.clear()
	var next_id: int = 0
	for entry: String in String(widget_info.get("hint_string", "")).split(",", false):
		var parts: PackedStringArray = entry.split(":")
		if parts.size() > 1:
			next_id = parts[1].to_int()
		_names.append(parts[0])
		_ids.append(next_id)
		next_id += 1
	slider.max_value = maxi(_names.size() - 1, 0)
	slider.set(&"tick_count", _names.size())


func _value(widget_value: Variant) -> void:
	var index: int = _ids.find(int(widget_value))
	if index == -1:
		return
	slider.value = index
	value_label.text = _names[index]


func _on_slider_value_changed(slider_value: float) -> void:
	_commit(_ids[int(slider_value)])
