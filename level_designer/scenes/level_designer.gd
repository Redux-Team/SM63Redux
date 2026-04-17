class_name LD
extends Node


static var _inst: LD

@export_group("Components", "_ld_")
@export var _ld_input_handler: LDInputHandler
@export var _ld_object_handler: LDObjectHandler
@export var _ld_tool_handler: LDToolHandler
@export var _ld_music_handler: LDMusicHandler
@export var _ld_history_handler: LDHistoryHandler
@export var _ld_save_load_handler: LDSaveLoadHandler
@export var _ld_viewport: LDViewport
@export var _ld_ui: LDUI


static func get_instance() -> LD:
	return _inst


static func get_input_handler() -> LDInputHandler:
	return get_instance()._ld_input_handler


static func get_object_handler() -> LDObjectHandler:
	return get_instance()._ld_object_handler


static func get_tool_handler() -> LDToolHandler:
	return get_instance()._ld_tool_handler


static func get_music_handler() -> LDMusicHandler:
	return get_instance()._ld_music_handler


static func get_save_load_handler() -> LDSaveLoadHandler:
	return get_instance()._ld_save_load_handler


static func get_history_handler() -> LDHistoryHandler:
	return get_instance()._ld_history_handler


static func get_editor_viewport() -> LDViewport:
	return get_instance()._ld_viewport


static func get_ui() -> LDUI:
	return get_instance()._ld_ui


static func is_ready() -> bool:
	return is_instance_valid(_inst)


func _init() -> void:
	_inst = self


func _ready() -> void:
	get_save_load_handler().load_raw_data({})
