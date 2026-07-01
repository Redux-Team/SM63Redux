@tool
class_name LDPropertyScenarioID
extends LDProperty


func _init() -> void:
	key = &"scenario_id"
	label = "Scenario ID"
	type = LDProperty.Type.INT
	default_value = 0
	exclusive = false


func clamp_value(value: Variant) -> Variant:
	return clampi(value as int, 0, Level.MAX_SCENARIO_COUNT)


func get_range() -> Vector2:
	return Vector2(0, Level.MAX_SCENARIO_COUNT)


func get_step() -> float:
	return 1
