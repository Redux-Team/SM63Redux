@tool
class_name BooleanWidget
extends AspectRatioContainer

signal value_changed(value: bool)

const CHECKMARK: Texture2D = preload("res://assets/textures/gui/widgets/boolean/checkmark.png")
const CHECKMARK_PRESSED: Texture2D = preload("res://assets/textures/gui/widgets/boolean/checkmark_pressed.png")
const CHECK_COOLDOWN: float = 0.1

@export var manual: bool = false:
	set(m):
		check_button.mouse_filter = Control.MOUSE_FILTER_IGNORE if m else Control.MOUSE_FILTER_PASS
		manual = m
@export var check_button: CheckBox
@export var check_texture: TextureRect

var hovering: bool = false
var toggled: bool = false


func _ready() -> void:
	check_button.button_down.connect(_on_button_down)
	check_button.toggled.connect(_on_toggled)
	check_button.mouse_entered.connect(_on_mouse_entered)
	check_button.mouse_exited.connect(_on_mouse_exited)


func set_toggled(new_value: bool, play_sfx: bool = true) -> void:
	if toggled == new_value:
		return
	toggled = new_value
	check_button.button_pressed = new_value
	if play_sfx:
		_play_sfx()
	_redraw()
	
	value_changed.emit(toggled)



func _on_toggled(toggled_on: bool) -> void:
	value_changed.emit(toggled_on)
	set_toggled(toggled_on, true)


func _on_button_down() -> void:
	check_texture.texture = CHECKMARK_PRESSED


func _redraw() -> void:
	check_texture.texture = CHECKMARK if toggled else null


func _play_sfx() -> void:
	if Engine.is_editor_hint():
		return
	if toggled:
		SFX.play(SFX.UI_CONFIRM)
	else:
		SFX.play(SFX.UI_BACK)


func _get_checkbox_value() -> bool:
	return check_button.button_pressed


func _on_mouse_entered() -> void:
	hovering = true


func _on_mouse_exited() -> void:
	hovering = false
