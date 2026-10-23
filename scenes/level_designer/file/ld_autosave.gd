class_name LDAutosave
extends LDComponent

const PATH: String = "user://ld/autosave.63rl"

@export var timer: Timer

var _saved_version: int = -1
var _task: int = -1


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and handler:
		save_now(false)


func _exit_tree() -> void:
	_wait()


func _setup() -> void:
	timer.timeout.connect(save_now)


func save_now(threaded: bool = true) -> void:
	var version: int = editor.history_handler.get_version()
	if not editor.file_handler.has_unsaved_changes() or version == _saved_version:
		return
	
	_saved_version = version
	var data: LevelData = editor.level_handler.capture()
	_wait()
	if threaded:
		_task = WorkerThreadPool.add_task(LevelFile.write.bind(PATH, data))
	else:
		LevelFile.write(PATH, data)


func has_recovery() -> bool:
	return FileAccess.file_exists(PATH)


func discard() -> void:
	_wait()
	_saved_version = editor.history_handler.get_version()
	if has_recovery():
		DirAccess.remove_absolute(PATH)


func _wait() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
