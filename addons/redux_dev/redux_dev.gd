@tool
extends EditorPlugin

const DEBUG_DOCK = preload("uid://cgx6mbayfubdw")
const DEBUG_HANDLER_PATH: String = "components/debug_handler.gd"

var debug_dock: EditorDock


func _enable_plugin() -> void:
	_setup_dock()
	add_autoload_singleton("DebugHandler", DEBUG_HANDLER_PATH)


func _disable_plugin() -> void:
	remove_autoload_singleton("DebugHandler")
	_teardown_dock()


func _enter_tree() -> void:
	if debug_dock == null:
		_setup_dock()


func _exit_tree() -> void:
	_teardown_dock()


func _setup_dock() -> void:
	debug_dock = EditorDock.new()
	debug_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UR
	debug_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL
	debug_dock.add_child(DEBUG_DOCK.instantiate())
	add_dock(debug_dock)


func _teardown_dock() -> void:
	if debug_dock == null:
		return
	
	remove_dock(debug_dock)
	debug_dock.queue_free()
	debug_dock = null


func _get_plugin_name() -> String:
	return "ReduxDev"
