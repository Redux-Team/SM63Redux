class_name State
extends Node

## State to inherit processing/behavior from.
@export var superstate: State
@export var lock_sprite_flipping: bool = false
@export_group("Default Sprite Animations")
## Plays sprite animations in sequential order, can be done manually by overriding
## [method _animation_handler] 
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var has_default_animations: bool = false
@export var animations: Array[StringName]


@export_group("Default Sound Effects")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var has_default_sfx: bool = false
@export var enter_sfx: SFXBank
@export var exit_sfx: SFXBank
@export var continuous_sfx: SFXBank


@export_group("Assertions", "assertions")
## Whether assertions are enabled, useful when tracking down incorrect behavior during a state.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "") var assertions_enabled: bool = false
@export_custom(PROPERTY_HINT_EXPRESSION, "") var assertions: String
## Perform an assertion check on enter.
@export var assertions_run_on_enter: bool = true
## Perform an assertion check each physics frame.
@export var assertions_run_on_process: bool = false
## Perform an assertion check on exit.
@export var assertions_run_on_exit: bool = false
## Perform an assertion check for the superstate.
@export var assertions_run_for_superstate: bool = false


var entity: Entity
var player: Player:
	get():
		if entity is Player:
			return entity as Player
		else:
			print_stack()
			push_error("The current entity is not of type \"Player\"")
			return entity
var sprite: AnimatedSprite2D
var state_machine: StateMachine
var state_name: StringName
var parent: Node:
	get():
		if get_parent() is not State:
			push_warning("State parent should be of type \"State\"")
		
		return get_parent()


func disable_processing() -> void:
	set_process(false)
	set_physics_process(false)
	
	if superstate:
		superstate.disable_processing()


func enable_processing() -> void:
	set_process(true)
	set_physics_process(true)
	
	if superstate:
		superstate.enable_processing()


func _on_enter(_from: StringName) -> void:
	pass


func _on_exit(_to: StringName) -> void:
	pass


func _animation_handler() -> void:
	if has_default_animations and not animations.is_empty():
		var chain: StateMachine.AnimationChain = state_machine.play_animation(animations.get(0))
		for i: int in range(animations.size() - 1):
			chain.then(animations.get(i + 1))


func _assertions_check(from: String = "") -> void:
	if not assertions_enabled or assertions.is_empty():
		return
		
	var assertions_list: PackedStringArray = assertions.split("\n", false)
		
	for line: String in assertions_list:
		line = line.strip_edges()
		if line.is_empty():
			continue
			
		var expr: Expression = Expression.new()
		var parse_err: Error = expr.parse(line, [])
		if parse_err != OK:
			push_warning("Failed to parse assertion: '%s'" % line)
			continue
			
		var result: Variant = expr.execute([], entity)
		if expr.has_execute_failed():
			push_error("Error executing assertion: '%s'" % line)
			continue
			
		if not bool(result):
			assert(false, "State: '%s' | Condition: '%s' | From: '%s'" % [self, line, from if from else "unknown"])
	
	if assertions_run_for_superstate:
		superstate._assertions_check("Substate '%s' > '%s'" % [self, from])


func _enter_tree() -> void:
	await owner.ready
	
	if !state_machine:
		push_error("State created without state machine bind: \"%s\"" % name)


func _to_string() -> String:
	return name
