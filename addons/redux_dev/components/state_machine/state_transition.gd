## A single directed transition between two [State] nodes.
##
## A [StateTransition] lives as a child [Node] of its source [State]; its [member target]
## points at the destination [State]. The [StateMachine] gathers each state's transition
## children, sorts them by [member priority], and fires the first eligible one on the physics
## clock. Attach a script extending [StateTransition] to override [method _should_transition]
## for custom conditions.
@tool
class_name StateTransition
extends Node


enum TransitionMode {
	AUTO,
	WAIT_UNTIL_DONE,
	WAIT_UNTIL_PARAMETER,
	WAIT_UNTIL_EXPRESSION,
	MANUAL,
}


## The [State] this transition leads to.
@export var target: State
## Transitions from the same state are checked highest-priority first.
@export var priority: float = 0.0
## Seconds this transition waits after becoming eligible before it actually fires.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var min_delay: float = 0.0
## When enabled, this transition is re-checked immediately upon entering its source state,
## letting the source state be skipped within a single frame.
@export var check_immediately: bool = false
@export var mode: TransitionMode = TransitionMode.AUTO:
	set(m):
		mode = m
		notify_property_list_changed()
## The label matched by [method StateMachine.trigger] for [constant MANUAL] transitions.
@export var label: String = ""
## The [member StateMachine.root_node] property polled for truthiness by [constant WAIT_UNTIL_PARAMETER].
@export var parameter_name: StringName = ""
## A GDScript expression evaluated against the root node for [constant WAIT_UNTIL_EXPRESSION].
@export_custom(PROPERTY_HINT_EXPRESSION, "") var expression: String = ""

var root_node: Node
var _expression: Expression


func _init_expression() -> void:
	_expression = null
	if expression.is_empty():
		return
	_expression = Expression.new()
	var err: int = _expression.parse(expression)
	if err != OK:
		push_error("StateTransition '%s': failed to parse expression \"%s\"" % [name, expression])
		_expression = null


func _evaluate_expression() -> bool:
	if not _expression or not root_node:
		return false
	var result: Variant = _expression.execute([], root_node)
	if _expression.has_execute_failed():
		push_error("StateTransition '%s': expression \"%s\" failed to execute" % [name, expression])
		return false
	return bool(result)


## Override to add a custom condition gate on top of this transition's [member mode].
func _should_transition() -> bool:
	return true


## Called just before the source state begins exiting for this transition.
func _on_before_transition() -> void:
	pass


## Called just after the target state has fully entered for this transition.
func _on_after_transition() -> void:
	pass


func _validate_property(property: Dictionary) -> void:
	if property.name == "parameter_name" and mode != TransitionMode.WAIT_UNTIL_PARAMETER:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "expression" and mode != TransitionMode.WAIT_UNTIL_EXPRESSION:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "label" and mode != TransitionMode.MANUAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR


func _to_string() -> String:
	return name
