@tool
class_name LDPropertyRNGSeed
extends LDProperty


func _init() -> void:
	key = &"rng_seed"
	label = "RNG Seed"
	type = LDProperty.Type.INT
	default_value = 0
	exclusive = false


func clamp_value(value: Variant) -> Variant:
	return clampi(value as int, 0, 999999999)


func get_range() -> Vector2:
	return Vector2(0, 999999999)


func get_step() -> float:
	return 1
