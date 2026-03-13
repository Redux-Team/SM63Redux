class_name LDHistoryHandler
extends LDComponent


var _undo_redo: UndoRedo = UndoRedo.new()


func _on_ready() -> void:
	pass


func _input(event: InputEvent) -> void:
	if not LD.get_input_handler().get_node_with_input_priority() is LDViewport:
		return
	
	if not event is InputEventKey or not event.is_pressed() or event.echo:
		return
	
	var ctrl: bool = event.is_command_or_control_pressed()
	
	if ctrl and event.keycode == KEY_Z:
		if event.shift_pressed:
			redo()
		else:
			undo()
	
	if ctrl and event.keycode == KEY_Y:
		redo()


func _on_input(_event: InputEvent) -> void:
	pass


func begin_action(action_name: String) -> void:
	_undo_redo.create_action(action_name)


func add_do(callable: Callable) -> void:
	_undo_redo.add_do_method(callable)


func add_undo(callable: Callable) -> void:
	_undo_redo.add_undo_method(callable)


func commit_action() -> void:
	_undo_redo.commit_action(false)


func undo() -> void:
	_undo_redo.undo()


func redo() -> void:
	_undo_redo.redo()
