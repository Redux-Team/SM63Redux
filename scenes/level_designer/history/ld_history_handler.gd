class_name LDHistoryHandler
extends LDHandler

signal changed

@export var max_steps: int = 200
@export var undo_button: BaseButton
@export var redo_button: BaseButton

var _undo_redo: UndoRedo = UndoRedo.new()


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_undo_redo.clear_history()
		_undo_redo.free()


func _unhandled_input(event: InputEvent) -> void:
	if editor.is_shortcut(event, &"ld_undo"):
		undo()
	elif editor.is_shortcut(event, &"ld_redo"):
		redo()
	else:
		return
	
	get_viewport().set_input_as_handled()


func _setup() -> void:
	_undo_redo.max_steps = max_steps
	_undo_redo.version_changed.connect(_on_version_changed)
	LD.bind_button(undo_button, undo)
	LD.bind_button(redo_button, redo)
	_refresh_buttons()


func create(action_name: String, merge: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE) -> Action:
	_undo_redo.create_action(action_name, merge)
	return Action.new(_undo_redo)


func undo() -> void:
	_undo_redo.undo()


func redo() -> void:
	_undo_redo.redo()


func clear() -> void:
	_undo_redo.clear_history()
	_refresh_buttons()
	changed.emit()


func get_version() -> int:
	return _undo_redo.get_version()


func _on_version_changed() -> void:
	_refresh_buttons()
	changed.emit()


func _refresh_buttons() -> void:
	LD.set_disabled(undo_button, not _undo_redo.has_undo())
	LD.set_disabled(redo_button, not _undo_redo.has_redo())


class Action:
	extends RefCounted
	
	var _undo_redo: UndoRedo
	
	
	func _init(undo_redo: UndoRedo) -> void:
		_undo_redo = undo_redo
	
	
	func do(callable: Callable) -> Action:
		_undo_redo.add_do_method(callable)
		return self
	
	
	func undo(callable: Callable) -> Action:
		_undo_redo.add_undo_method(callable)
		return self
	
	
	func keep_on_do(object: Object) -> Action:
		_undo_redo.add_do_reference(object)
		return self
	
	
	func keep_on_undo(object: Object) -> Action:
		_undo_redo.add_undo_reference(object)
		return self
	
	
	func commit() -> void:
		_undo_redo.commit_action(true)
