## Helper class to easily pack/unpack data.
class_name Packer


static func merge_deep(base: Dictionary, override: Dictionary) -> Dictionary:
	var result: Dictionary = base.duplicate(true)
	for key in override.keys():
		if result.has(key) and typeof(result[key]) == TYPE_DICTIONARY and typeof(override[key]) == TYPE_DICTIONARY:
			result[key] = merge_deep(result[key], override[key])
		else:
			result[key] = override[key]
	return result


static func generate_uuid() -> String:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.randomize()
	var b: PackedByteArray = PackedByteArray()
	for i: int in 16:
		b.append(rng.randi() % 256)
	b[6] = (b[6] & 0x0F) | 0x40
	b[8] = (b[8] & 0x3F) | 0x80
	return "%02x%02x%02x%02x-%02x%02x-%02x%02x-%02x%02x-%02x%02x%02x%02x%02x%02x" % [
		b[0], b[1], b[2], b[3], b[4], b[5], b[6], b[7],
		b[8], b[9], b[10], b[11], b[12], b[13], b[14], b[15]
	]


static func array_to_vec2(array: Variant) -> Vector2:
	if array is Array and array.size() >= 2:
		return Vector2(float(array[0]), float(array[1]))
	return Vector2.ZERO


static func array_to_packed_vec2(array: Variant) -> PackedVector2Array:
	var packed: PackedVector2Array = []
	if array is Array and array.size() >= 1:
		for v_array: Array in array:
			packed.append(Vector2(float(v_array[0]), float(v_array[1])))
	return packed


static func array_to_color(array: Variant) -> Color:
	if array is Array and array.size() == 4:
		return Color(float((array)[0]), float((array)[1]), float((array)[2]), float((array)[3]))
	return Color.WHITE


static func deserialize_json_variant(value: Variant) -> Variant:
	if value is Array and value.size() == 2:
		return array_to_vec2(value)
	if value is Array and value.size() == 4:
		return array_to_color(value)
	return value


static func serialize_json_variant(value: Variant) -> Variant:
	if value is Vector2:
		return vec2_to_array(value)
	if value is Vector2i:
		return [value.x, value.y]
	if value is Color:
		return color_to_array(value)
	return value


static func vec2_to_array(vector2: Vector2) -> Array:
	return [vector2.x, vector2.y]


static func color_to_array(color: Color) -> Array:
	return [color.r, color.g, color.b, color.a]
