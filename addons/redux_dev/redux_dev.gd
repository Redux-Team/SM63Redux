@tool
class_name ReduxPlugin
extends EditorPlugin

const SHOW_INTERNAL: bool = true

const DEBUG_DOCK = preload("uid://cgx6mbayfubdw")
const DEBUG_HANDLER_UID: String = "components/debug_dock/debug_handler.gd"

var _debug_dock: EditorDock


func _enable_plugin() -> void:
	add_autoload_singleton("DebugHandler", DEBUG_HANDLER_UID)


func _disable_plugin() -> void:
	remove_autoload_singleton("DebugHandler")


func _enter_tree() -> void:
	_setup_docks()


func _exit_tree() -> void:
	_teardown_docks()


func _setup_docks() -> void:
	_debug_dock = EditorDock.new()
	_debug_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UR
	_debug_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL
	_debug_dock.add_child(DEBUG_DOCK.instantiate())
	add_dock(_debug_dock)


func _teardown_docks() -> void:
	if _debug_dock == null:
		return
	
	remove_dock(_debug_dock)
	_debug_dock.queue_free()
	_debug_dock = null


func _get_plugin_name() -> String:
	return "ReduxDev"
