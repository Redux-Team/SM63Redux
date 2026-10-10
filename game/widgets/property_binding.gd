class_name PropertyBinding
extends RefCounted

signal changed(value: Variant)

var label: String
var info: Dictionary
var _getter: Callable
var _setter: Callable


func _init(getter: Callable, setter: Callable, binding_label: String = "", binding_info: Dictionary = {}) -> void:
	_getter = getter
	_setter = setter
	label = binding_label
	info = binding_info


static func from_property(target: Object, property: StringName, binding_label: String = "", info_overrides: Dictionary = {}) -> PropertyBinding:
	var info: Dictionary = {}
	for candidate: Dictionary in target.get_property_list():
		if candidate.get("name") == property:
			info = candidate
			break
	var setter: Callable = func(value: Variant) -> void:
		target.set(property, value)
	var resolved_label: String = binding_label if not binding_label.is_empty() else String(property).capitalize()
	return PropertyBinding.new(target.get.bind(property), setter, resolved_label, info.merged(info_overrides, true))


func get_value() -> Variant:
	return _getter.call()


func set_value(value: Variant) -> void:
	if get_value() == value:
		return
	_setter.call(value)
	refresh()


func refresh() -> void:
	changed.emit(get_value())


func kind() -> StringName:
	if info.has("widget"):
		return info.get("widget")
	match info.get("hint", PROPERTY_HINT_NONE):
		PROPERTY_HINT_ENUM:
			return &"enum"
		PROPERTY_HINT_RANGE:
			return &"range"
		PROPERTY_HINT_ARRAY_TYPE:
			return StringName("Array[%s]" % info.get("hint_string"))
	return StringName(type_string(info.get("type", typeof(get_value()))))
