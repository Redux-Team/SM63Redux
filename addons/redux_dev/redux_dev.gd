@tool
extends EditorPlugin


const DEBUG_DOCK = preload("uid://cgx6mbayfubdw")
const DEBUG_HANDLER_UID: String = "components/debug_dock/debug_handler.gd"
const STATE_MACHINE_EDITOR = preload("uid://dpvtgmjtc1tpk")

var _debug_dock: EditorDock
var _state_machine_editor_dock: EditorDock
var _editor: EditorStateMachineEditor


func _enable_plugin() -> void:
	add_autoload_singleton("DebugHandler", DEBUG_HANDLER_UID)


func _disable_plugin() -> void:
	remove_autoload_singleton("DebugHandler")


func _enter_tree() -> void:
	_setup_docks()


func _exit_tree() -> void:
	_teardown_docks()


func _edit(object: Object) -> void:
	if object is StateMachine:
		_editor.load_state_machine(object as StateMachine)


func _handles(object: Object) -> bool:
	if object is not Node:
		return false
	
	if object is StateMachine:
		_state_machine_editor_dock.make_visible()
	else:
		_state_machine_editor_dock.close()
	
	return true


func _setup_docks() -> void:
	_debug_dock = EditorDock.new()
	_debug_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UR
	_debug_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL
	_debug_dock.add_child(DEBUG_DOCK.instantiate())
	add_dock(_debug_dock)
	
	_state_machine_editor_dock = EditorDock.new()
	_state_machine_editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	_editor = STATE_MACHINE_EDITOR.instantiate()
	_state_machine_editor_dock.add_child(_editor)
	add_dock(_state_machine_editor_dock)


func _teardown_docks() -> void:
	if _debug_dock == null:
		return
	
	remove_dock(_debug_dock)
	_debug_dock.queue_free()
	_debug_dock = null
	
	remove_dock(_state_machine_editor_dock)
	_state_machine_editor_dock.queue_free()
	_state_machine_editor_dock = null
	_editor = null


func _get_plugin_name() -> String:
	return "ReduxDev"
