class_name ModifierStack
extends RefCounted


var _values: Dictionary[StringName, float] = {}
var _lifetimes: Dictionary[StringName, float] = {}


func set_modifier(key: StringName, value: float, duration: float = 0.0) -> void:
	_values.set(key, value)
	if duration > 0.0:
		_lifetimes.set(key, duration)
	else:
		_lifetimes.erase(key)


func clear_modifier(key: StringName) -> void:
	_values.erase(key)
	_lifetimes.erase(key)


func has_modifier(key: StringName) -> bool:
	return _values.has(key)


func clear() -> void:
	_values.clear()
	_lifetimes.clear()


func tick(delta: float) -> void:
	if _lifetimes.is_empty():
		return
	
	for key: StringName in _lifetimes.keys():
		var remaining: float = _lifetimes.get(key) - delta
		if remaining > 0.0:
			_lifetimes.set(key, remaining)
			continue
		
		clear_modifier(key)


func product() -> float:
	var result: float = 1.0
	for key: StringName in _values:
		result *= _values.get(key)
	
	return result
