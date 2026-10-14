class_name LDSettingsPanel
extends LDPanel

@export var screen: SettingsScreen
@export var exit_button: BaseButton
@export var action_row: HBoxContainer

var _resolved: bool = false


func _setup() -> void:
	super()
	exit_button.reparent(action_row, false)
	action_row.move_child(exit_button, 0)
	LD.bind_button(exit_button, editor.quit_to_title)
	screen.closed.connect(_on_screen_closed)


func _on_open() -> void:
	_resolved = false
	screen.open()
	Singleton.set_discord_activity("Configuring settings...")


func _on_close() -> void:
	Singleton.set_discord_activity("Editing a level")
	if not _resolved:
		_resolved = true
		screen.cancel()


func _on_screen_closed() -> void:
	_resolved = true
	close()
