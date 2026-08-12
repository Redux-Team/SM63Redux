class_name LD
extends Node


## Emitted when the editor is suspended or resumed. Components use it to drop the few hooks that
## live outside the editor's own subtree, which leaving the tree does not cover on its own.
signal suspended_changed(suspended: bool)


static var _inst: LD

var _suspended: bool = false


@export_group("Components", "_ld_")
@export var _ld_input_handler: LDInputHandler
@export var _ld_object_handler: LDObjectHandler
@export var _ld_stamp_handler: LDStampHandler
@export var _ld_tag_handler: LDTagHandler
@export var _ld_scenario_handler: LDScenarioHandler
@export var _ld_background_handler: LDBackgroundHandler
@export var _ld_tool_handler: LDToolHandler
@export var _ld_music_handler: LDMusicHandler
@export var _ld_history_handler: LDHistoryHandler
@export var _ld_clipboard_handler: LDClipboardHandler
@export var _ld_save_load_handler: LDSaveLoadHandler
@export var _ld_viewport: LDViewport
@export var _ld_ui: LDUI


static func get_instance() -> LD:
	return _inst


static func get_input_handler() -> LDInputHandler:
	return get_instance()._ld_input_handler


static func get_object_handler() -> LDObjectHandler:
	return get_instance()._ld_object_handler


static func get_stamp_handler() -> LDStampHandler:
	return get_instance()._ld_stamp_handler


static func get_tag_handler() -> LDTagHandler:
	return get_instance()._ld_tag_handler


static func get_scenario_handler() -> LDScenarioHandler:
	return get_instance()._ld_scenario_handler


static func get_background_handler() -> LDBackgroundHandler:
	return get_instance()._ld_background_handler


static func get_tool_handler() -> LDToolHandler:
	return get_instance()._ld_tool_handler


static func get_music_handler() -> LDMusicHandler:
	return get_instance()._ld_music_handler


static func get_save_load_handler() -> LDSaveLoadHandler:
	return get_instance()._ld_save_load_handler


static func get_history_handler() -> LDHistoryHandler:
	return get_instance()._ld_history_handler


static func get_clipboard_handler() -> LDClipboardHandler:
	return get_instance()._ld_clipboard_handler


static func get_editor_viewport() -> LDViewport:
	return get_instance()._ld_viewport


static func get_ui() -> LDUI:
	return get_instance()._ld_ui


static func get_level() -> LDLevel:
	return LDLevel._inst


static func get_area() -> LDArea:
	return LDLevel.get_active_area()


static func is_ready() -> bool:
	return is_instance_valid(_inst)


func is_suspended() -> bool:
	return _suspended


## Stops the editor dead: nothing in the subtree processes, receives input, or gets notifications.
## Used while a playtest is on screen, where the editor is kept in memory but must be inert.
func set_suspended(value: bool) -> void:
	if _suspended == value:
		return
	_suspended = value
	process_mode = PROCESS_MODE_DISABLED if value else PROCESS_MODE_INHERIT
	suspended_changed.emit(value)


func _init() -> void:
	_inst = self


func _ready() -> void:
	var level: LDLevel = LDLevel.new()
	level.name = "Level"
	get_editor_viewport().get_root().add_child(level)

	level.add_area("Area 1")
	level.set_active_area_index(0)


func _exit_tree() -> void:
	get_save_load_handler()
