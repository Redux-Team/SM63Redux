static func run_test() -> void:
	var flag: ObjectProperty = _property(ObjectProperty.Type.BOOL, true)
	assert(flag.get_variant_type() == TYPE_BOOL)
	assert(flag.coerce(null) == true)
	assert(flag.coerce(0) == false)
	assert(typeof(flag.coerce(1)) == TYPE_BOOL)
	assert(typeof(flag.random_value()) == TYPE_BOOL)
	assert(flag.to_info() == { "type": TYPE_BOOL })
	
	var count: ObjectProperty = _property(ObjectProperty.Type.INT, 2)
	count.min_value = 0.0
	count.max_value = 10.0
	count.step = 2.0
	assert(count.coerce(-5) == 0)
	assert(count.coerce(4.9) == 4)
	assert(count.coerce("7") == 7)
	assert(count.coerce(99) == 10)
	assert(
			count.to_info()
			== {
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_RANGE,
				"hint_string": "0.0,10.0,2.0",
				"format": "%d",
			}
	)
	for i: int in 20:
		var value: Variant = count.random_value()
		assert(typeof(value) == TYPE_INT)
		assert(value >= 0 and value <= 10)
		assert(value % 2 == 0)
	
	var unbounded: ObjectProperty = _property(ObjectProperty.Type.FLOAT, 1.5)
	unbounded.step = 0.25
	assert(unbounded.coerce(null) == 1.5)
	assert(unbounded.coerce(1e9) == 1e9)
	assert(unbounded.coerce(3) == 3.0)
	assert(typeof(unbounded.coerce(3)) == TYPE_FLOAT)
	assert(unbounded.random_value() == 1.5)
	assert(unbounded.to_info() == { "type": TYPE_FLOAT, "step": 0.25 })
	
	var angle: ObjectProperty = _property(ObjectProperty.Type.FLOAT, 0.0)
	angle.min_value = -180.0
	angle.max_value = 180.0
	angle.wrap_value = true
	assert(is_equal_approx(angle.coerce(190.0), -170.0))
	assert(is_equal_approx(angle.coerce(-540.0), -180.0))
	angle.max_value = INF
	assert(angle.coerce(1000.0) == 1000.0)
	assert(angle.coerce(-1000.0) == -180.0)
	
	var choice: ObjectProperty = _property(ObjectProperty.Type.ENUM, 1)
	choice.options = PackedStringArray(["Small", "Medium", "Large"])
	assert(choice.get_variant_type() == TYPE_INT)
	assert(choice.coerce(null) == 1)
	assert(choice.coerce(7) == 2)
	assert(choice.coerce(-3) == 0)
	assert(
			choice.to_info()
			== {
				"type": TYPE_INT,
				"hint": PROPERTY_HINT_ENUM,
				"hint_string": "Small,Medium,Large",
			}
	)
	for i: int in 20:
		assert(choice.random_value() in [0, 1, 2])
	choice.options = PackedStringArray()
	assert(choice.coerce(5) == 0)
	assert(choice.random_value() == 0)
	
	var text: ObjectProperty = _property(ObjectProperty.Type.STRING, "Hello")
	assert(text.coerce(null) == "Hello")
	assert(text.coerce(12) == "12")
	assert(text.to_info() == { "type": TYPE_STRING })
	text.multiline = true
	text.bbcode = true
	assert(text.to_info() == { "type": TYPE_STRING, "widget": &"text", "bbcode": true })
	
	var offset: ObjectProperty = _property(ObjectProperty.Type.VECTOR2, Vector2(1, 2))
	assert(offset.coerce(null) == Vector2(1, 2))
	assert(offset.coerce(Vector2i(3, 4)) == Vector2(3, 4))
	assert(offset.random_value() == Vector2(1, 2))
	var tint: ObjectProperty = _property(ObjectProperty.Type.COLOR, Color.RED)
	assert(tint.coerce(null) == Color.RED)
	assert(tint.coerce("#00ff00") == Color.GREEN)
	var points: ObjectProperty = \
			_property(ObjectProperty.Type.PACKED_VECTOR2, PackedVector2Array([Vector2.ONE]))
	assert(points.coerce(null) == PackedVector2Array([Vector2.ONE]))
	assert(points.get_variant_type() == TYPE_PACKED_VECTOR2_ARRAY)
	
	assert(_property(ObjectProperty.Type.INT, 0).get_label() == "Platform Width")
	var labelled: ObjectProperty = _property(ObjectProperty.Type.INT, 0)
	labelled.label = "Width"
	assert(labelled.get_label() == "Width")
	
	var object: GameObject = GameObject.new()
	var target: Node2D = Node2D.new()
	target.name = "Target"
	object.add_child(target)
	var position: ObjectProperty = _property(ObjectProperty.Type.FLOAT, 0.0)
	position.targets = [^"Target", ^"Missing"]
	position.member = &"position:x"
	position.apply(object, 12.0)
	assert(target.position == Vector2(12, 0))
	var method: ObjectProperty = _property(ObjectProperty.Type.FLOAT, 0.0)
	method.targets = [^"Target"]
	method.method = &"set_rotation"
	method.apply(object, 0.5)
	assert(target.rotation == 0.5)
	var inert: ObjectProperty = _property(ObjectProperty.Type.FLOAT, 0.0)
	inert.targets = [^"Target"]
	inert.apply(object, 99.0)
	assert(target.position == Vector2(12, 0))
	object.free()


static func _property(type: ObjectProperty.Type, default_value: Variant) -> ObjectProperty:
	var property: ObjectProperty = ObjectProperty.new()
	property.key = &"platform_width"
	property.type = type
	property.default_value = default_value
	return property
