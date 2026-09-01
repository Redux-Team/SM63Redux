class_name LDHistoryHandler
extends Node

signal history_changed


var _undo_redo: UndoRedo = UndoRedo.new()
## Objects detached by a delete action. The undo lambdas can re-add them, so they cannot be
## freed at delete time; ownership sits here until the handler itself goes away.
var _detached: Array[Node] = []


## UndoRedo is an Object, not RefCounted, so it has to be freed by hand or it (and every
## action Callable it holds) outlives the editor scene.
func _notification(what: int) -> void:
	if what != NOTIFICATION_PREDELETE:
		return
	
	for node: Node in _detached:
		if is_instance_valid(node) and not node.get_parent():
			node.free()
	
	_detached.clear()
	
	if is_instance_valid(_undo_redo):
		_undo_redo.free()


## Hands ownership of objects a delete action detached from the tree to this handler, so they
## are freed with it instead of being orphaned.
func track_detached(nodes: Array) -> void:
	for node: Node in nodes:
		if not _detached.has(node):
			_detached.append(node)


func _input(event: InputEvent) -> void:
	if LD.has_input_capture():
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


## Records one undoable step and performs it. [param do] runs immediately and on every redo,
## [param undo] reverses it. Callers must not apply the change themselves as well.
func push(action_name: String, do: Callable, undo_action: Callable) -> void:
	_undo_redo.create_action(action_name)
	_undo_redo.add_do_method(do)
	_undo_redo.add_undo_method(undo_action)
	_undo_redo.commit_action(true)
	history_changed.emit()


func undo() -> void:
	_undo_redo.undo()
	history_changed.emit()


func redo() -> void:
	_undo_redo.redo()
	history_changed.emit()


func can_undo() -> bool:
	return _undo_redo.has_undo()


func can_redo() -> bool:
	return _undo_redo.has_redo()
