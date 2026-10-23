extends Node

const LEVEL_DESIGNER: String = "uid://b6ofp5p155oy2"
const KICKOUT_DELAY: float = 2.0
const RELEASE_DELAY: float = 0.08
const LAUNCHED_STATE: String = "launched"

@export var level: Level
@export var return_button: BaseButton

var _returning: bool = false


func _ready() -> void:
	return_button.pressed.connect(return_to_editor)
	level.kickout_requested.connect(_on_kickout)
	var session: EditorSession = Singleton.editor_session
	if session.level:
		level.load_data(session.level, session.area_uuid)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		return_to_editor()


func return_to_editor() -> void:
	if _returning or Singleton.is_transitioning():
		return
	
	_returning = true
	GDSS.set_state(return_button, LAUNCHED_STATE)
	await get_tree().create_timer(RELEASE_DELAY).timeout
	(
			Singleton.build_screen_transition()
			.set_center()
			.set_loading_delay(0.0)
			.load(level.dismantle)
			.set_swap(Singleton.editor_session.resume_or_open.bind(get_tree(), LEVEL_DESIGNER))
			.done()
	)


func _on_kickout() -> void:
	await get_tree().create_timer(KICKOUT_DELAY).timeout
	return_to_editor()
