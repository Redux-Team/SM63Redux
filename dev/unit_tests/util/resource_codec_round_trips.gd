static func run_test() -> void:
	assert(ResourceCodec.encode(5) == 5)
	assert(ResourceCodec.encode("text") == "text")
	assert(ResourceCodec.encode(Vector2(1.0, 2.0)) == Vector2(1.0, 2.0))
	assert(ResourceCodec.decode(null) == null)
	assert(ResourceCodec.decode({ "plain": 1 }) == { "plain": 1 })
	
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(12.0, 34.0)
	var encoded: Dictionary = ResourceCodec.encode(rectangle)
	assert(encoded[ResourceCodec.CLASS_KEY] == "RectangleShape2D")
	assert((encoded[ResourceCodec.VALUES_KEY] as Dictionary)["size"] == Vector2(12.0, 34.0))
	assert(not (encoded[ResourceCodec.VALUES_KEY] as Dictionary).has("resource_path"))
	assert(not (encoded[ResourceCodec.VALUES_KEY] as Dictionary).has("script"))
	var decoded: RectangleShape2D = ResourceCodec.decode(encoded)
	assert(decoded != rectangle)
	assert(decoded.size == rectangle.size)
	
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 9.0
	var shapes: Array = ResourceCodec.decode(ResourceCodec.encode([rectangle, 3, circle]))
	assert(shapes.size() == 3)
	assert((shapes[0] as RectangleShape2D).size == rectangle.size)
	assert(shapes[1] == 3)
	assert(is_equal_approx((shapes[2] as CircleShape2D).radius, 9.0))
	
	var saved: Resource = load("res://dev/unit_tests/_unit_tester.tres")
	var reference: Dictionary = ResourceCodec.encode(saved)
	assert(reference.keys() == [ResourceCodec.UID_KEY])
	assert((reference[ResourceCodec.UID_KEY] as String).begins_with("uid://"))
	assert(ResourceCodec.decode(reference) == saved)
	assert(
			ResourceCodec.decode(
					{
						ResourceCodec.UID_KEY: ("res://dev/unit_tests/missing_resource.tres"),
					}
			)
			== null
	)
	
	var property: ObjectProperty = ObjectProperty.new()
	property.key = &"speed"
	property.type = ObjectProperty.Type.INT
	property.default_value = 7
	property.min_value = 1.0
	property.max_value = 9.0
	property.options = PackedStringArray(["a", "b"])
	property.targets = [^"Sprite2D", ^"Game"]
	var property_data: Dictionary = ResourceCodec.encode(property)
	assert(property_data[ResourceCodec.CLASS_KEY] == "ObjectProperty")
	var property_back: ObjectProperty = ResourceCodec.decode(
			JSON.to_native(JSON.parse_string(JSON.stringify(JSON.from_native(property_data))))
	)
	assert(property_back.key == &"speed")
	assert(property_back.type == ObjectProperty.Type.INT)
	assert(property_back.default_value == 7)
	assert(property_back.max_value == 9.0)
	assert(property_back.options == PackedStringArray(["a", "b"]))
	assert(property_back.targets == [^"Sprite2D", ^"Game"])
	assert(property_back.targets.is_typed())
	
	assert(ResourceCodec.decode({ ResourceCodec.CLASS_KEY: "NotARealClassName" }) == null)
	
	var typed_target: ObjectProperty = ObjectProperty.new()
	ResourceCodec.assign(typed_target, &"targets", [^"A", null, ^"B"])
	assert(typed_target.targets == [^"A", ^"B"])
	assert(typed_target.targets.get_typed_builtin() == TYPE_NODE_PATH)
	ResourceCodec.assign(typed_target, &"label", "Speed")
	assert(typed_target.label == "Speed")
