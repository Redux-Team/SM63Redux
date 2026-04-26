@tool
class_name LDPropertyPalette
extends LDProperty

enum PaletteRandom {
	NONE,
	PLACEMENT,
	ALWAYS
}

@export var amount: int
@export var random: PaletteRandom = PaletteRandom.NONE


func _init() -> void:
	key = &"palette"
	label = "Palette"
	type = LDProperty.Type.INT
	default_value = 0


@warning_ignore("unused_parameter")
func apply(obj: LDObject, value: Variant) -> void:
	for shader_obj: CanvasItem in obj.shader_objects:
		shader_obj.material.set_shader_parameter(&"palette_index", value)

@warning_ignore("unused_parameter")
func _on_first_placement(obj: LDObject, value: Variant) -> void:
	if random == PaletteRandom.PLACEMENT:
		obj.set_property(key, randi_range(0, 6))


func clamp_value(value: Variant) -> Variant:
	return clampi(value, 0, amount - 1)


func get_range() -> Vector2:
	return Vector2(0, amount - 1)


func get_step() -> float:
	return 1


func get_arrow_step() -> float:
	return 1
