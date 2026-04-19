extends LevelObject

@export var arrow: SmartSprite2D


func _handle_property(property_name: String, property_value: Variant) -> void:
	if property_name == "arrow_rotation":
		arrow.rotation_degrees = property_value
	else:
		super(property_name, property_value)
