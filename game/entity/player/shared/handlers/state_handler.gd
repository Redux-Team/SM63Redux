class_name PlayerStateHandler
extends Node


var _is_dry: bool = true
var _is_running: bool = false
var _is_spinning: bool = false
var _is_diving: bool = false
var _is_falling: bool = false
var _is_swimming: bool = false
var _is_using_hover_fludd: bool = false
var _lock_flipping: bool = false


func is_dry() -> bool:
	return _is_dry


func set_dry(value: bool) -> void:
	_is_dry = value


func is_running() -> bool:
	return _is_running


func set_running(value: bool) -> void:
	_is_running = value


func is_spinning() -> bool:
	return _is_spinning


func set_spinning(value: bool) -> void:
	_is_spinning = value


func is_diving() -> bool:
	return _is_diving


func set_diving(value: bool) -> void:
	_is_diving = value


func is_falling() -> bool:
	return _is_falling


func set_falling(value: bool) -> void:
	_is_falling = value


func is_swimming() -> bool:
	return _is_swimming


func set_swimming(value: bool) -> void:
	_is_swimming = value


func is_using_hover_fludd() -> bool:
	return _is_using_hover_fludd


func set_using_hover_fludd(value: bool) -> void:
	_is_using_hover_fludd = value


func is_lock_flipping() -> bool:
	return _lock_flipping


func set_lock_flipping(value: bool) -> void:
	_lock_flipping = value
