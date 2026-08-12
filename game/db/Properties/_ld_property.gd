@tool
class_name LDProperty
extends Resource

## One editable field on a placed object. Everything about a property is data, so adding one means
## filling in a resource rather than writing a script: inline on the object that owns it, or as a
## shared file under game/db/Properties/ when several objects want the same field.


enum Type { BOOL, INT, FLOAT, STRING, VECTOR2, COLOR, ARRAY_VECTOR2, OPTION }
## What editing the value should do to the editor object. Most properties do nothing here, because
## the object reads them back through [method LDObject.get_property] when it needs them.
enum Apply { NONE, PROPERTY, SHADER_PARAM, METHOD }


@export var key: StringName
@export var label: String
@export var type: Type = Type.FLOAT:
	set(t):
		type = t
		notify_property_list_changed()
@export var default_value: Variant
## Hidden properties still save and load, they just get no widget in the properties panel.
@export var visible_in_editor: bool = true
@export var exclusive: bool = false

@export_group("Range")
@export var min_value: float = -INF
@export var max_value: float = INF
@export var step: float = 1.0
@export var arrow_step: float = 1.0
## Values run off one end and reappear at the other instead of stopping at it.
@export var wrap: bool = false

@export_group("Options")
## Fixed choices for an OPTION property. Leave it empty to let the object list them at runtime
## through [method LDObject.get_property_options], for choices that come from a directory.
@export var options: PackedStringArray

@export_group("Apply")
@export var apply_mode: Apply = Apply.NONE
## A property path (sub-properties like "block_size:x" work), a shader uniform, or a method name.
@export var apply_target: NodePath
## Rolls a starting value between the range bounds the first time the object is placed.
@export var randomize_on_placement: bool = false
## Key of another property this one is measured from, so a widget can draw it as an offset
## rather than an absolute (a sign's arrow angle on top of the sign's own rotation).
@export var relative_to: StringName


func apply(obj: LDObject, value: Variant) -> void:
	if apply_mode == Apply.NONE or apply_target.is_empty():
		return

	var applied: Variant = coerce(value)
	match apply_mode:
		Apply.PROPERTY:
			obj.set_indexed(apply_target, applied)
		Apply.SHADER_PARAM:
			obj.set_shader_parameter(StringName(String(apply_target)), applied)
		Apply.METHOD:
			obj.call(StringName(String(apply_target)), applied)


func _on_first_placement(obj: LDObject, _value: Variant) -> void:
	if randomize_on_placement and is_bounded():
		obj.set_property(key, randi_range(int(min_value), int(max_value)))


## Forces a value into this property's declared type, so a level loaded from JSON (where a Vector2
## arrives as a two-element array) behaves the same as one edited in the panel.
func coerce(value: Variant) -> Variant:
	match type:
		Type.BOOL:
			return bool(value)
		Type.INT:
			return int(value)
		Type.FLOAT:
			return float(value)
		Type.STRING, Type.OPTION:
			return str(value) if value != null else ""
		Type.VECTOR2:
			return value if value is Vector2 else Packer.array_to_vec2(value)
		Type.COLOR:
			return value if value is Color else Packer.array_to_color(value)
		Type.ARRAY_VECTOR2:
			return Packer.to_packed_vec2(value)
	return value


func clamp_value(value: Variant) -> Variant:
	var result: Variant = coerce(value)
	match type:
		Type.INT, Type.FLOAT:
			var numeric: float = float(result)
			if wrap and is_bounded():
				numeric = wrapf(numeric, min_value, max_value)
			else:
				if is_finite(min_value):
					numeric = maxf(numeric, min_value)
				if is_finite(max_value):
					numeric = minf(numeric, max_value)
			return int(numeric) if type == Type.INT else numeric
		Type.VECTOR2:
			var vector: Vector2 = result
			if is_finite(min_value):
				vector = vector.max(Vector2(min_value, min_value))
			if is_finite(max_value):
				vector = vector.min(Vector2(max_value, max_value))
			return vector
	return result


func get_range() -> Vector2:
	return Vector2(min_value, max_value)


func get_step() -> float:
	return step


func get_arrow_step() -> float:
	return arrow_step


func is_bounded() -> bool:
	return is_finite(min_value) and is_finite(max_value)


func is_unbound() -> bool:
	return not is_finite(min_value) and not is_finite(max_value)


func _validate_property(property: Dictionary) -> void:
	var numeric: bool = type == Type.INT or type == Type.FLOAT
	var hidden: bool = false

	match property.name:
		&"min_value", &"max_value":
			hidden = not numeric and type != Type.VECTOR2
		&"step", &"arrow_step":
			hidden = not numeric and type != Type.VECTOR2
		&"wrap", &"randomize_on_placement":
			hidden = not numeric
		&"options":
			hidden = type != Type.OPTION

	if hidden:
		property.usage = PROPERTY_USAGE_NO_EDITOR
