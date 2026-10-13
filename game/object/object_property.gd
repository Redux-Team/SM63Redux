@tool
class_name ObjectProperty
extends Resource

enum Type {
	BOOL,
	INT,
	FLOAT,
	STRING,
	VECTOR2,
	COLOR,
	ENUM,
	PACKED_VECTOR2,
}

const VARIANT_TYPES: Dictionary[Type, Variant.Type] = {
	Type.BOOL: TYPE_BOOL,
	Type.INT: TYPE_INT,
	Type.FLOAT: TYPE_FLOAT,
	Type.STRING: TYPE_STRING,
	Type.VECTOR2: TYPE_VECTOR2,
	Type.COLOR: TYPE_COLOR,
	Type.ENUM: TYPE_INT,
	Type.PACKED_VECTOR2: TYPE_PACKED_VECTOR2_ARRAY,
}

@export var key: StringName
@export var label: String
@export var group: StringName
@export var type: Type = Type.FLOAT
@export var default_value: Variant
@export var hidden: bool = false
@export_group("Range")
@export var min_value: float = -INF
@export var max_value: float = INF
@export var step: float = 0.0
@export var wrap_value: bool = false
@export var randomize_on_place: bool = false
@export_group("Enum")
@export var options: PackedStringArray
@export_group("Target")
@export var targets: Array[NodePath] = [^"."]
@export var member: StringName
@export var method: StringName


func get_variant_type() -> Variant.Type:
	return VARIANT_TYPES.get(type)


func get_label() -> String:
	return label if not label.is_empty() else String(key).capitalize()


func coerce(value: Variant) -> Variant:
	var source: Variant = default_value if value == null else value
	return clamp_value(type_convert(source, get_variant_type()))


func clamp_value(value: Variant) -> Variant:
	match type:
		Type.INT, Type.FLOAT:
			var number: float = value
			if wrap_value and is_finite(min_value) and is_finite(max_value):
				number = wrapf(number, min_value, max_value)
			else:
				number = clampf(number, min_value, max_value)
			return type_convert(number, get_variant_type())
		Type.ENUM:
			return clampi(value, 0, maxi(options.size() - 1, 0))
	
	return value


func random_value() -> Variant:
	match type:
		Type.BOOL:
			return randi() % 2 == 0
		Type.INT, Type.FLOAT:
			if is_finite(min_value) and is_finite(max_value):
				var number: float = randf_range(min_value, max_value)
				if step > 0.0:
					number = snappedf(number, step)
				return coerce(number)
		Type.ENUM:
			return randi() % maxi(options.size(), 1)
	
	return coerce(null)


func apply(object: GameObject, value: Variant) -> void:
	if member.is_empty() and method.is_empty():
		return
	
	for path: NodePath in targets:
		var target: Node = object.get_node_or_null(path)
		if target == null:
			continue
		
		if method.is_empty():
			target.set_indexed(NodePath(member), value)
		else:
			target.call(method, value)


func to_info() -> Dictionary:
	var info: Dictionary = {"type": get_variant_type()}
	match type:
		Type.ENUM:
			info.set("hint", PROPERTY_HINT_ENUM)
			info.set("hint_string", ",".join(options))
		Type.INT, Type.FLOAT:
			if is_finite(min_value) and is_finite(max_value):
				info.set("hint", PROPERTY_HINT_RANGE)
				info.set("hint_string", "%s,%s,%s" % [min_value, max_value, step])
			else:
				info.set("step", step)
	
	return info
