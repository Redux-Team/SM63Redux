static func run_test() -> void:
	var style: StyleProperty = StyleProperty.new()
	assert(style.coerce(null) == "")
	assert(style.coerce(StyleProperty.DEFAULT_LABEL) == "")
	assert(style.coerce("Brick") == "Brick")
	var style_info: Dictionary = style.to_info()
	assert(style_info.get("type") == TYPE_STRING)
	assert(style_info.get("hint") == PROPERTY_HINT_ENUM)
	assert((style_info.get("hint_string") as String).split(",").get(0) == StyleProperty.DEFAULT_LABEL)
	for style_name: String in PolygonStyleRegistry.get_names(style.style_kind):
		assert(style_name in (style_info.get("hint_string") as String).split(","))
