class_name LD
extends Node

static var _inst: LD

@export_group("Components", "_ld_")
@export var _ld_input_handler: LDInputHandler
@export var _ld_music_handler: LDMusicHandler
@export var _ld_viewport: LDViewport
@export var _ld_ui: LDUI


static func get_instance() -> LD:
	return _inst


static func get_input_handler() -> LDInputHandler:
	return get_instance()._ld_input_handler


static func get_music_handler() -> LDMusicHandler:
	return get_instance()._ld_music_handler


static func get_editor_viewport() -> LDViewport:
	return get_instance()._ld_viewport


static func get_ui() -> LDUI:
	return get_instance()._ld_ui


func _ready() -> void:
	_inst = self
	get_editor_viewport().set_input_priority()
