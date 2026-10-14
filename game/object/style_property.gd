@tool
class_name StyleProperty
extends ObjectProperty

const DEFAULT_LABEL: String = "Default"

@export var style_kind: PolygonStyleRegistry.Kind


func coerce(value: Variant) -> Variant:
	var text: String = str(value) if value != null else ""
	return "" if text == DEFAULT_LABEL else text


func to_info() -> Dictionary:
	var names: PackedStringArray = [DEFAULT_LABEL]
	names.append_array(PolygonStyleRegistry.get_names(style_kind))
	return {"type": TYPE_STRING, "hint": PROPERTY_HINT_ENUM, "hint_string": ",".join(names)}
