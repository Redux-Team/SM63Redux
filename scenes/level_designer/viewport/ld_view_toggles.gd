class_name LDViewToggles
extends LDComponent

@export var reset_camera_button: BaseButton
@export var focus_button: BaseButton
@export var modulation_button: BaseButton
@export var grid_button: BaseButton
@export var grid: LDGrid


func _setup() -> void:
	var level: LDLevelHandler = editor.level_handler
	LD.bind_button(reset_camera_button, editor.viewport_handler.camera_control.reset)
	focus_button.set_pressed_no_signal(level.focus_enabled)
	modulation_button.set_pressed_no_signal(level.modulation_enabled)
	focus_button.toggled.connect(func(on: bool) -> void: level.focus_enabled = on)
	modulation_button.toggled.connect(func(on: bool) -> void: level.modulation_enabled = on)
	grid_button.set_pressed_no_signal(grid.canvas.visible)
	grid_button.toggled.connect(func(on: bool) -> void: grid.canvas.visible = on)
