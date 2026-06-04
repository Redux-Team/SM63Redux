@tool
extends LDObjectSprite

@export var arrow: SmartSprite2D


func _apply_property(key: StringName, value: Variant) -> void:
	if key == &"rotation:arrow":
		arrow.rotation_degrees = value
	else:
		super(key, value)
