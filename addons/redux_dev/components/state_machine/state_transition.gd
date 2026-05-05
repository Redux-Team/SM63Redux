@tool
class_name StateTransition
extends Resource

@export var __from_uuid: String
@export var __to_uuid: String

## Called to determine whether the state machine should transition.
func _should_transition() -> bool:
	return false

## Called before the transition begins.
func _on_before_transition() -> void:
	pass

## Called after the transition completes.
func _on_after_transition() -> void:
	pass


func _validate_property(property: Dictionary) -> void:
	if property.name.begins_with("__") and not ReduxPlugin.SHOW_INTERNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
