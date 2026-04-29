@tool
extends EditorPlugin

const DEBUG_DOCK = preload("uid://cgx6mbayfubdw")
const DEBUG_HANDLER_UID: String = "components/debug_dock/debug_dock.gd"
const STATE_MACHINE_EDITOR = preload("uid://dpvtgmjtc1tpk")

var debug_dock: EditorDock
var state_machine_editor_dock: EditorDock
var _decorator: EditorSceneTreeDecorator
var editor: EditorStateMachineEditor


func _enable_plugin() -> void:
	_setup_docks()
	add_autoload_singleton("DebugHandler", DEBUG_HANDLER_UID)


func _disable_plugin() -> void:
	remove_autoload_singleton("DebugHandler")
	_teardown_docks()


func _enter_tree() -> void:
	if debug_dock == null:
		_setup_docks()
	_decorator = EditorSceneTreeDecorator.new(self)
	call_deferred(&"_setup_decorator")


func _exit_tree() -> void:
	_teardown_docks()
	if _decorator:
		_decorator.teardown()
		_decorator = null


func _setup_docks() -> void:
	debug_dock = EditorDock.new()
	debug_dock.default_slot = EditorDock.DOCK_SLOT_LEFT_UR
	debug_dock.available_layouts = EditorDock.DOCK_LAYOUT_VERTICAL
	debug_dock.add_child(DEBUG_DOCK.instantiate())
	add_dock(debug_dock)
	
	state_machine_editor_dock = EditorDock.new()
	state_machine_editor_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	editor = STATE_MACHINE_EDITOR.instantiate()
	state_machine_editor_dock.add_child(editor)
	add_dock(state_machine_editor_dock)


func _setup_decorator() -> void:
	_decorator.setup()
	_decorator.refresh()


func _teardown_docks() -> void:
	if debug_dock == null:
		return
	
	remove_dock(debug_dock)
	debug_dock.queue_free()
	debug_dock = null
	
	remove_dock(state_machine_editor_dock)
	state_machine_editor_dock.queue_free()
	state_machine_editor_dock = null
	editor = null


func _save_external_data() -> void:
	if _decorator:
		_decorator.call_deferred(&"refresh")


func _get_plugin_name() -> String:
	return "ReduxDev"
