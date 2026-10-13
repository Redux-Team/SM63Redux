class_name State
extends Node


@export var effects: StateEffects

var machine: StateMachine
var entity: Entity
var sprite: SmartSprite2D
var time: float = 0.0
var frames: int = 0
var sfx_frame_index: int = -1
var sfx_tracked: Node
var chain_index: int = 0
var mask_backup: int = -1
var last_variant: StringName = &""


func _bind() -> void:
	pass


func _enter() -> void:
	pass


func _exit() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _render_tick(_delta: float) -> void:
	pass


func _next() -> StringName:
	return &""


func _on_chain_advance() -> void:
	if effects:
		effects.advance_chain(self)


func is_current() -> bool:
	return machine != null and machine.get_state() == self


func is_active() -> bool:
	return machine != null and machine.is_active(name)


func _to_string() -> String:
	return String(name)
