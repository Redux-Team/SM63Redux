extends PropertyWidget

const AXES: PackedStringArray = ["X", "Y"]

@export var label: Label
@export var axes: VBoxContainer

var _bindings: Array[PropertyBinding] = []


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	for child: Node in axes.get_children():
		child.queue_free()
	_bindings.clear()
	for axis: int in AXES.size():
		var axis_info: Dictionary = widget_info.duplicate()
		axis_info.erase("widget")
		axis_info["type"] = TYPE_FLOAT
		if widget_info.has("hint_string"):
			axis_info["hint"] = PROPERTY_HINT_RANGE
		else:
			axis_info.erase("hint")
		var axis_binding: PropertyBinding = PropertyBinding.new(
				_get_axis.bind(axis),
				_set_axis.bind(axis),
				AXES[axis],
				axis_info,
		)
		axes.add_child(PropertyWidget.create(axis_binding))
		_bindings.append(axis_binding)


func _value(_widget_value: Variant) -> void:
	for axis_binding: PropertyBinding in _bindings:
		axis_binding.refresh()


func _get_axis(axis: int) -> float:
	var vector: Vector2 = Vector2(binding.get_value())
	return vector.x if axis == 0 else vector.y


func _set_axis(value: float, axis: int) -> void:
	var vector: Vector2 = Vector2(binding.get_value())
	if axis == 0:
		vector.x = value
	else:
		vector.y = value
	
	_commit(type_convert(vector, typeof(binding.get_value())))
