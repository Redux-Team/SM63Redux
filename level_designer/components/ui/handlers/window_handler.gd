class_name LDUIWindowHandler
extends Node

## Drives a single shared LDWindow shell, binding it to one of several content scenes on
## demand instead of keeping one window node per panel. Enforces "one window open at a
## time" and returns the bound content node so callers can drive it, e.g.
## LD.get_ui().get_window_handler().toggle_tag_editor().

const OBJECT_BROWSER: StringName = &"object_browser"
const OBJECT_PROPERTIES: StringName = &"object_properties"
const LAYER_PROPERTIES: StringName = &"layer_properties"
const AREA_EDITOR: StringName = &"area_editor"
const STAMP_EDITOR: StringName = &"stamp_editor"
const SCENARIO_EDITOR: StringName = &"scenario_editor"
const TAG_EDITOR: StringName = &"tag_editor"
const BACKGROUND_EDITOR: StringName = &"background_editor"
const PICKER: StringName = &"picker"


## Emitted when the active window changes: the opened window's id, or &"" when the
## window closes. The UI chrome listens to this to highlight the matching panel button.
signal active_changed(id: StringName)


@export var _window: LDWindow
@export var _window_defs: Array[LDWindowDef]


## Content instances, created once and reused so their state survives close/reopen.
var _instances: Dictionary[StringName, Control] = {}
var _defs: Dictionary[StringName, LDWindowDef] = {}
## Id of the window currently popped in (empty when nothing is open).
var _active_id: StringName = &""


func _ready() -> void:
	for def: LDWindowDef in _window_defs:
		_defs[def.id] = def
		var content: Control = def.scene.instantiate()
		_instances[def.id] = content
		_window.add_content(content)
	_window.popped_out.connect(_on_window_popped_out)

	var browser: LDObjectBrowser = _instances.get(OBJECT_BROWSER) as LDObjectBrowser
	if browser:
		browser.category_changed.connect(_on_browser_category_changed)


#region Typed toggles (return the bound content)

func toggle_object_browser() -> LDObjectBrowser:
	return toggle(OBJECT_BROWSER) as LDObjectBrowser


func toggle_object_properties() -> LDObjectPropertyList:
	return toggle(OBJECT_PROPERTIES) as LDObjectPropertyList


func toggle_layer_properties() -> Control:
	return toggle(LAYER_PROPERTIES)


func toggle_area_editor() -> LDAreaEditor:
	return toggle(AREA_EDITOR) as LDAreaEditor


func toggle_stamp_editor() -> LDStampEditor:
	return toggle(STAMP_EDITOR) as LDStampEditor


func toggle_scenario_editor() -> LDScenarioEditor:
	return toggle(SCENARIO_EDITOR) as LDScenarioEditor


func toggle_tag_editor() -> LDTagEditor:
	return toggle(TAG_EDITOR) as LDTagEditor


func toggle_background_editor() -> LDBackgroundEditor:
	return toggle(BACKGROUND_EDITOR) as LDBackgroundEditor


#endregion


#region Generic window control

## Opens the window bound to `id`, or closes it if it's already the active one. Returns
## the content node (null if another window is already open and blocks this one).
func toggle(id: StringName) -> Control:
	if _active_id == id:
		_window.popout()
		return _instances.get(id)
	return open(id)


## Opens the window for `id`. No-op (returns null) if a different window is already open.
func open(id: StringName) -> Control:
	if not _defs.has(id):
		return null
	if _active_id != &"" and _active_id != id:
		return null

	var def: LDWindowDef = _defs[id]
	var content: Control = _instances[id]
	_window.bind(content, def.title, def.close_on_back_input, def.window_scale)
	_active_id = id
	LD.get_input_handler().set_input_priority(LD.get_ui())
	_window.popin()
	active_changed.emit(id)
	return content


func close() -> void:
	if _active_id != &"":
		_window.popout()


func is_window_open() -> bool:
	return _active_id != &""


func get_content(id: StringName) -> Control:
	return _instances.get(id)


func get_object_browser() -> LDObjectBrowser:
	return _instances.get(OBJECT_BROWSER) as LDObjectBrowser


#endregion


#region Pickers

func open_tag_picker(title: String, on_confirm: Callable) -> void:
	var picker: LDPickerDialog = _instances[PICKER] as LDPickerDialog
	picker.setup_ids(title, LD.get_tag_handler().get_all_tags())
	_wire_picker(picker, on_confirm)
	open(PICKER)


func _wire_picker(picker: LDPickerDialog, on_confirm: Callable) -> void:
	picker.confirmed.connect(func(id: String) -> void:
		on_confirm.call(id)
		close()
	, CONNECT_ONE_SHOT)
	picker.cancelled.connect(close, CONNECT_ONE_SHOT)


#endregion


#region Internal

func _on_browser_category_changed(category_name: String) -> void:
	if _active_id == OBJECT_BROWSER:
		_window.title = "Objects - " + (category_name if category_name else "All")


func _on_window_popped_out() -> void:
	if _active_id != &"":
		LD.get_input_handler().remove_input_priority(LD.get_ui())
		_active_id = &""
		active_changed.emit(&"")


#endregion
