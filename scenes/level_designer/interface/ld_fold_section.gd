class_name LDFoldSection
extends VBoxContainer

signal toggled(expanded: bool)

@export var toggle_button: Button
@export var content: VBoxContainer
@export var expanded_icon: Texture2D
@export var collapsed_icon: Texture2D


func _ready() -> void:
	toggle_button.toggled.connect(_on_toggled)


func setup(title: String, expanded: bool) -> void:
	toggle_button.text = title
	toggle_button.set_pressed_no_signal(expanded)
	_apply(expanded)


func _on_toggled(expanded: bool) -> void:
	_apply(expanded)
	SFX.play(SFX.LD_SELECT if expanded else SFX.LD_BACK)
	toggled.emit(expanded)


func _apply(expanded: bool) -> void:
	content.visible = expanded
	toggle_button.icon = expanded_icon if expanded else collapsed_icon
