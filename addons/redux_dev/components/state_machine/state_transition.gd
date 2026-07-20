## A single directed transition between two [State] nodes.
##
## A [StateTransition] is a lightweight [Resource] stored in its source [State]'s
## [member State.transitions] array; [member target] points at the destination [State] as a
## path relative to the owning [StateMachine]. The machine checks each state's transitions
## in array order on the physics clock and fires the first eligible one. Attach a script
## extending [StateTransition] to override [method _should_transition] for custom conditions.
## [br][br]
## Transitions are shared, immutable data: every instance of a scene reuses the same
## resources, so they must never hold per-entity mutable state.
@tool
class_name StateTransition
extends Resource


enum TransitionMode {
	AUTO,
	WAIT_UNTIL_DONE,
	WAIT_UNTIL_EXPRESSION,
}


## Path to the destination [State], relative to the owning [StateMachine].
@export var target: NodePath
@export var mode: TransitionMode = TransitionMode.AUTO:
	set(m):
		mode = m
		notify_property_list_changed()
## A GDScript expression evaluated against the root node for [constant WAIT_UNTIL_EXPRESSION].
@export_custom(PROPERTY_HINT_EXPRESSION, "") var expression: String = ""
## Seconds this transition waits after becoming eligible before it actually fires.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var min_delay: float = 0.0
## When enabled, this transition is re-checked immediately upon entering its source state,
## letting the source state be skipped within a single frame.
@export var check_immediately: bool = false

var _expression: Expression


func _ensure_parsed() -> void:
	if _expression or expression.is_empty():
		return
	var parsed: Expression = Expression.new()
	var err: int = parsed.parse(expression)
	if err != OK:
		push_error("StateTransition '%s': failed to parse expression \"%s\"" % [resource_name, expression])
		return
	_expression = parsed


func _evaluate_expression(root: Node) -> bool:
	if not _expression or not root:
		return false
	var result: Variant = _expression.execute([], root)
	if _expression.has_execute_failed():
		push_error("StateTransition '%s': expression \"%s\" failed to execute" % [resource_name, expression])
		return false
	return bool(result)


## Override to add a custom condition gate on top of this transition's [member mode].
func _should_transition(machine: StateMachine) -> bool:
	return true


## Called just before the source state begins exiting for this transition.
func _on_before_transition(machine: StateMachine) -> void:
	pass


## Called just after the target state has fully entered for this transition.
func _on_after_transition(machine: StateMachine) -> void:
	pass


func _validate_property(property: Dictionary) -> void:
	if property.name == "expression" and mode != TransitionMode.WAIT_UNTIL_EXPRESSION:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _to_string() -> String:
	return resource_name
