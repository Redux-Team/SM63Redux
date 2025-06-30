extends AspectRatioContainer

const CHECKMARK_PRESSED = preload("res://assets/textures/gui/widgets/boolean/checkmark_pressed.png")
const CHECKMARK = preload("res://assets/textures/gui/widgets/boolean/checkmark.png")
const CHECK_COOLDOWN: float = 0.1

@export var check_button: CheckBox
@export var check_texture: TextureRect
var hovering: bool = false


func _ready() -> void:
	check_button.button_down.connect(_on_button_down)
	check_button.toggled.connect(_on_toggled)
	check_button.mouse_entered.connect(_on_mouse_entered)
	check_button.mouse_exited.connect(_on_mouse_exited)


func _on_button_down() -> void:
	check_texture.texture = CHECKMARK_PRESSED


func _on_toggled(toggled_on: bool) -> void:
	if toggled_on:
		check_texture.texture = CHECKMARK
		SFX.play(SFX.UI_CONFIRM)
	else:
		check_texture.texture = null
		SFX.play(SFX.UI_BACK)


func _check() -> void:
	if not hovering:
		check_button.button_pressed = !check_button.button_pressed


func _on_mouse_entered() -> void:
	hovering = true


func _on_mouse_exited() -> void:
	hovering = false
