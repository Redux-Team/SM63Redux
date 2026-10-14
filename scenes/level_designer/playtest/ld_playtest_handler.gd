class_name LDPlaytestHandler
extends LDHandler

const PLAYTEST_SCENE: String = "res://scenes/playtest/playtest.tscn"

@export var playtest_button: BaseButton


func _setup() -> void:
	LD.bind_button(playtest_button, start)


func _unhandled_input(event: InputEvent) -> void:
	if editor.is_shortcut(event, &"ld_playtest"):
		start()
		get_viewport().set_input_as_handled()


func start() -> void:
	if Singleton.is_transitioning():
		return
	
	var session: EditorSession = Singleton.editor_session
	session.level = editor.level_handler.capture()
	session.area_uuid = editor.level_handler.active_area.uuid
	editor.file_handler.autosave.save_now()
	Singleton.build_screen_transition() \
		.set_center() \
		.set_loading_delay(0.0) \
		.set_swap(session.suspend_into.bind(get_tree(), load(PLAYTEST_SCENE))) \
		.done()
