class_name Mode
extends Node


var machine: ModeMachine
var host: Node
var time: float = 0.0
var frames: int = 0
var permanent: bool = false


func _bind() -> void:
	pass


func _is_available() -> bool:
	return true


func _enter() -> void:
	pass


func _tick(_delta: float) -> void:
	pass


func _exit() -> void:
	pass


func end() -> void:
	var multi: MultiModeMachine = machine as MultiModeMachine
	if multi:
		multi.end(name)


func is_running() -> bool:
	return machine != null and machine.is_running(name)


func _to_string() -> String:
	return String(name)
