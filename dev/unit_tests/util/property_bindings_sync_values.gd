@tool
static func run_test() -> void:
	var target: ObjectProperty = ObjectProperty.new()
	target.min_value = 3.0
	var binding: PropertyBinding = PropertyBinding.from_property(target, &"min_value")
	assert(binding.label == "Min Value")
	assert(binding.info.get("type") == TYPE_FLOAT)
	assert(binding.get_value() == 3.0)
	assert(binding.kind() == &"float")
	
	var emitted: Array = []
	binding.changed.connect(func(value: Variant) -> void: emitted.append(value))
	binding.set_value(5.0)
	assert(target.min_value == 5.0)
	assert(emitted == [5.0])
	binding.set_value(5.0)
	assert(emitted == [5.0])
	target.min_value = 6.0
	binding.refresh()
	assert(emitted == [5.0, 6.0])
	
	var overridden: PropertyBinding = PropertyBinding.from_property(target, &"options", "Choices", {"hint": PROPERTY_HINT_ENUM})
	assert(overridden.label == "Choices")
	assert(overridden.kind() == &"enum")
	
	var store: Dictionary = {"value": "abc"}
	var custom: PropertyBinding = PropertyBinding.new(func() -> Variant: return store.get("value"), func(value: Variant) -> void: store.set("value", value))
	assert(custom.label == "")
	assert(custom.kind() == &"String")
	custom.set_value("xyz")
	assert(store.get("value") == "xyz")
	
	assert(PropertyBinding.kind_of({"widget": &"text", "hint": PROPERTY_HINT_ENUM}) == &"text")
	assert(PropertyBinding.kind_of({"hint": PROPERTY_HINT_ENUM, "type": TYPE_INT}) == &"enum")
	assert(PropertyBinding.kind_of({"hint": PROPERTY_HINT_RANGE, "type": TYPE_FLOAT}) == &"range")
	assert(PropertyBinding.kind_of({"hint": PROPERTY_HINT_FLAGS, "type": TYPE_INT}) == &"flags")
	assert(PropertyBinding.kind_of({"hint": PROPERTY_HINT_ARRAY_TYPE, "hint_string": "InputEvent", "type": TYPE_ARRAY}) == &"Array[InputEvent]")
	assert(PropertyBinding.kind_of({"type": TYPE_BOOL}) == &"bool")
	assert(PropertyBinding.kind_of({"type": TYPE_COLOR}) == &"Color")
	assert(PropertyBinding.kind_of({}) == &"Nil")
