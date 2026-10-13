class_name LD
extends Node

const TITLE_SCREEN: String = "uid://dp3ocrpop234v"
const ACTIVE_CLASS: String = "Active"

@export var world: Node2D
@export var camera: Camera2D
@export var input_map: LDInputMap
@export_group("Handlers")
@export var history_handler: LDHistoryHandler
@export var level_handler: LDLevelHandler
@export var object_handler: LDObjectHandler
@export var tool_handler: LDToolHandler
@export var viewport_handler: LDViewportHandler
@export var file_handler: LDFileHandler
@export var playtest_handler: LDPlaytestHandler
@export var interface_handler: LDInterfaceHandler


func _ready() -> void:
	input_map.apply()
	world.process_mode = Node.PROCESS_MODE_DISABLED
	for child: Node in get_children():
		if child is LDHandler:
			(child as LDHandler).setup(self)
	
	Singleton.set_discord_activity("Editing a level")


static func bind_button(button: BaseButton, callable: Callable) -> void:
	if button:
		button.pressed.connect(callable)


static func set_active(button: Control, active: bool) -> void:
	if button == null or GDSS.get_classes(button).has(ACTIVE_CLASS) == active:
		return
	
	if active:
		GDSS.add_class(button, ACTIVE_CLASS)
	else:
		GDSS.remove_class(button, ACTIVE_CLASS)


static func set_disabled(button: BaseButton, disabled: bool) -> void:
	if button == null or button.disabled == disabled:
		return
	
	button.disabled = disabled
	GDSS.refresh(button)


func set_suspended(suspended: bool) -> void:
	process_mode = Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_INHERIT


func accepts_shortcuts() -> bool:
	var focus: Control = get_viewport().gui_get_focus_owner()
	return not (focus is LineEdit or focus is TextEdit) and interface_handler.current_panel is not LDSettingsPanel


func is_shortcut(event: InputEvent, action: StringName) -> bool:
	return accepts_shortcuts() and event.is_action_pressed(action, false, true)


func quit_to_title() -> void:
	file_handler.confirm_discard(_leave)


func _leave() -> void:
	file_handler.discard_autosave()
	Singleton.editor_session.discard()
	Singleton.editor_session.level = null
	Singleton.build_screen_transition() \
		.set_center() \
		.set_destination(TITLE_SCREEN) \
		.done()
