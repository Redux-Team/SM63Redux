extends Node

const LEVEL_DESIGNER: String = "uid://b6ofp5p155oy2"

@export var level: Level
@export var return_button: BaseButton


func _ready() -> void:
	return_button.pressed.connect(return_to_editor)
	var session: EditorSession = Singleton.editor_session
	if session.level:
		level.load_data(session.level, session.area_uuid)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		return_to_editor()


func return_to_editor() -> void:
	if Singleton.is_transitioning():
		return
	
	Singleton.build_screen_transition() \
		.set_center() \
		.set_loading_delay(0.0) \
		.set_swap(Singleton.editor_session.resume_or_open.bind(get_tree(), LEVEL_DESIGNER)) \
		.done()
