class_name PropertyBinding
extends RefCounted

signal changed(value: Variant)

var label: String
var info: Dictionary
var _getter: Callable
var _setter: Callable


static func from_property(
		target: Object,
		property: StringName,
		binding_label: String = "",
		info_overrides: Dictionary = {},
) -> PropertyBinding:
	var prop_info: Dictionary = {}
	for candidate: Dictionary in target.get_property_list():
		if candidate["name"] == property:
			prop_info = candidate
			break
	var setter: Callable = func(value: Variant) -> void:
		target.set(property, value)
	var resolved_label: String = \
			binding_label if not binding_label.is_empty() else String(property).capitalize()
	return PropertyBinding.new(
			target.get.bind(property),
			setter,
			resolved_label,
			prop_info.merged(info_overrides, true),
	)


static func kind_of(property_info: Dictionary) -> StringName:
	if property_info.has("widget"):
		return property_info["widget"]
	match property_info.get("hint", PROPERTY_HINT_NONE):
		PROPERTY_HINT_ENUM:
			return &"enum"
		PROPERTY_HINT_RANGE:
			return &"range"
		PROPERTY_HINT_FLAGS:
			return &"flags"
		PROPERTY_HINT_ARRAY_TYPE:
			return StringName("Array[%s]" % property_info.get("hint_string"))
	return StringName(type_string(property_info.get("type", TYPE_NIL)))


func _init(
		getter: Callable,
		setter: Callable,
		binding_label: String = "",
		binding_info: Dictionary = {},
) -> void:
	_getter = getter
	_setter = setter
	label = binding_label
	info = binding_info


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
	return kind_of(info if info.has("type") else info.merged({ "type": typeof(get_value()) }))
