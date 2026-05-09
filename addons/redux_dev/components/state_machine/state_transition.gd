@tool
class_name StateTransition
extends Resource


enum TransitionMode {
	AUTO,
	WAIT_UNTIL_DONE,
	WAIT_UNTIL_PARAMETER,
	WAIT_UNTIL_EXPRESSION,
	MANUAL,
}


@export_tool_button("Edit Script", "Script") var _edit_script_btn: Callable:
	get:
		return func() -> void:
			var s: Script = get_script() as Script
			if s and s != StateTransition:
				EditorInterface.edit_script(s)
				EditorInterface.set_main_screen_editor("Script")
			else:
				EditorStateMachineEditor.prompt_transition_script(self)

@export var mode: TransitionMode = TransitionMode.AUTO:
	set(m):
		mode = m
		notify_property_list_changed()
@export var priority: float = 0.0
@export var transition_time: float = 0.0
@export var label: String = ""
@export var parameter_name: StringName = ""
## When enabled, this allows the transition to fire immediately before entering a state,
## effectively skipping that state if this is true. Otherwise, the state is actuve for a frame.
@export var check_immediately: bool = false
@export_custom(PROPERTY_HINT_EXPRESSION, "") var expression: String = ""

@export_group("Internal", "__")
@export var __from_uuid: String
@export var __to_uuid: String
@export var __from_node_uuid: String
@export var __to_node_uuid: String

var root_node: Node
var payload: Dictionary[StringName, Variant] = {}
var _expression: Expression


func _init() -> void:
	resource_local_to_scene = true


func _init_expression() -> void:
	if expression.is_empty():
		return
	_expression = Expression.new()
	_expression.parse(expression)


func _evaluate_expression() -> bool:
	if not _expression or not root_node:
		return false
	var result: Variant = _expression.execute([], root_node)
	if _expression.has_execute_failed():
		return false
	return bool(result)


func _should_transition() -> bool:
	return true


func _on_before_transition() -> void:
	pass


func _on_after_transition() -> void:
	pass


func _validate_property(property: Dictionary) -> void:
	if property.name.begins_with("__") and not ReduxPlugin.SHOW_INTERNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "parameter_name" and mode != TransitionMode.WAIT_UNTIL_PARAMETER:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "expression" and mode != TransitionMode.WAIT_UNTIL_EXPRESSION:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "label" and mode != TransitionMode.MANUAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
