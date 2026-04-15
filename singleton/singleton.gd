@tool
extends Node


var _input_handler: InputHandler = InputHandler.new()
var _tree_hook: TreeHook = TreeHook.new()


func _init() -> void:
	add_child(_input_handler)
	add_child(_tree_hook)


func get_input_handler() -> InputHandler:
	return _input_handler

## This is a hook which can be used by custom resources to allow syncing
## with the SceneTree process.
func get_tree_hook() -> TreeHook:
	return _tree_hook


class InputHandler:
	extends Node
	
	signal input_type_changed
	
	enum InputType {
		KEYBOARD,
		CONTROLLER,
		TOUCH
	}
	
	var _current_input_type: InputType
	
	func _unhandled_input(event: InputEvent) -> void:
		var _old_input_type: InputType = _current_input_type
		
		if event is InputEventKey:
			_current_input_type = InputType.KEYBOARD
		elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
			_current_input_type = InputType.CONTROLLER
		elif event is InputEventScreenTouch or event is InputEventScreenDrag:
			_current_input_type = InputType.TOUCH
		
		if _old_input_type != _current_input_type:
			input_type_changed.emit()
	
	
	func get_current_input_type() -> InputType:
		return _current_input_type
	
	
	func is_using_keyboard() -> bool:
		return _current_input_type == InputType.KEYBOARD
	
	func is_using_controller() -> bool:
		return _current_input_type == InputType.CONTROLLER
	
	func is_using_touch() -> bool:
		return _current_input_type == InputType.TOUCH


class TreeHook:
	extends Node
	
	var _last_delta: float
	var _frame_bound_callables: Dictionary[Callable, Array]
	
	
	func _process(delta: float) -> void:
		for callable: Callable in _frame_bound_callables:
			callable.callv(_frame_bound_callables.get(callable))
		
		_last_delta = delta
	
	
	func get_last_delta() -> float:
		return _last_delta
	
	
	func bind_callable_to_frame(callable: Callable, parameters: Array) -> void:
		_frame_bound_callables.set(callable, parameters)
