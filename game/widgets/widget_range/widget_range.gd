extends PropertyWidget

const MAX_TICK_STEPS: int = 10

@export var label: Label
@export var slider: UISlider
@export var value_label: Label

var _format: String = "%s"
var _max_text: String = ""
var _update_on_release: bool = false


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	var range_hint: PackedStringArray = String(widget_info.get("hint_string", "0,1")).split(",")
	slider.min_value = range_hint.get(0).to_float()
	slider.max_value = range_hint.get(1).to_float()
	slider.step = range_hint.get(2).to_float() if range_hint.size() > 2 and range_hint.get(2).is_valid_float() else 0.0
	var steps: int = roundi((slider.max_value - slider.min_value) / slider.step) if slider.step > 0.0 else 0
	slider.set(&"tick_count", steps + 1 if steps <= MAX_TICK_STEPS else 0)
	_format = widget_info.get("format", "%s")
	_max_text = widget_info.get("max_text", "")
	_update_on_release = widget_info.get("update_on_release", false)


func _value(widget_value: Variant) -> void:
	slider.value = widget_value
	value_label.text = _display(widget_value)


func _on_slider_value_changed(slider_value: float) -> void:
	value_label.text = _display(slider_value)
	if not (_update_on_release and slider.is_held()):
		_commit_slider()


func _display(number: float) -> String:
	return _max_text if not _max_text.is_empty() and number >= slider.max_value else _format % number


func _on_slider_drag_ended(_value_changed: bool) -> void:
	if _update_on_release:
		_commit_slider()


func _commit_slider() -> void:
	_commit(type_convert(slider.value, typeof(binding.get_value())))
