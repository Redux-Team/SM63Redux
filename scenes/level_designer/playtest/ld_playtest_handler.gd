class_name LDPlaytestHandler
extends LDHandler

const PLAYTEST_SCENE: String = "res://scenes/playtest/playtest.tscn"
const RELEASE_DELAY: float = 0.08
const LAUNCHED_STATE: String = "launched"

@export var playtest_button: BaseButton

var _starting: bool = false


func _setup() -> void:
	LD.bind_button(playtest_button, start)


func _enter_tree() -> void:
	if is_node_ready():
		GDSS.clear_state.call_deferred(playtest_button)


func _unhandled_input(event: InputEvent) -> void:
	if editor.is_shortcut(event, &"ld_playtest"):
		start()
		get_viewport().set_input_as_handled()


func start() -> void:
	if _starting or Singleton.is_transitioning():
		return
	
	_starting = true
	GDSS.set_state(playtest_button, LAUNCHED_STATE)
	await get_tree().create_timer(RELEASE_DELAY).timeout
	_starting = false
	Singleton.build_screen_transition() \
		.set_center() \
		.set_loading_delay(0.0) \
		.set_swap(_enter_playtest) \
		.done()


func _enter_playtest() -> void:
	var session: EditorSession = Singleton.editor_session
	session.level = editor.level_handler.capture()
	session.area_uuid = editor.level_handler.active_area.uuid
	editor.file_handler.autosave.save_now()
	session.suspend_into(get_tree(), load(PLAYTEST_SCENE))
