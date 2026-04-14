extends Node


var _input_handler: InputHandler


func _init() -> void:
	_input_handler = InputHandler.new()


func get_input_handler() -> InputHandler:
	return _input_handler

class InputHandler:
	extends Node
	
	signal input_type_changed
	
	enum InputType {
		KEYBOARD,
		CONTROLLER,
		TOUCH
	}
	
	var _current_input_type: InputType
	
	func _input(event: InputEvent) -> void:
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
