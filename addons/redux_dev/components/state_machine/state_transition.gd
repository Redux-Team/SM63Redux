class_name StateTransition
extends Resource

## Called to determine whether the state machine should transition.
func _should_transition() -> bool:
	return false

## Called before the transition begins.
func _on_before_transition() -> void:
	pass

## Called after the transition completes.
func _on_after_transition() -> void:
	pass
