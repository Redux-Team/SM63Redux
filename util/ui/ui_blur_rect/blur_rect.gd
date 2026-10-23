@tool
class_name BlurRect
extends ColorRect

@export_range(0, 16) var blur_strength: float = 3.0:
	set(bs):
		blur_strength = bs
		if material:
			material.set_shader_parameter(&"blur", bs)
@export var tint: Color = Color(0, 0, 0, 0):
	set(t):
		tint = t
		if material:
			material.set_shader_parameter(&"tint", t)


func _init() -> void:
	if not material:
		var mat: ShaderMaterial = ShaderMaterial.new()
		material = mat
		mat.shader = preload("uid://wxepa6euigw5")


func _validate_property(property: Dictionary) -> void:
	if property.name == "color":
		property.usage = PROPERTY_USAGE_NONE
