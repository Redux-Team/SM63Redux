class_name Mode
extends Node


var machine: ModeMachine
var host: Node
var time: float = 0.0
var frames: int = 0


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


func is_running() -> bool:
	return machine != null and machine.get_running() == self


func _to_string() -> String:
	return String(name)
