class_name LDObjectGroup
extends PanelContainer

@export var list: HFlowContainer
@export var toggle_button: Button
@export var expanded_icon: Texture2D
@export var collapsed_icon: Texture2D


func _ready() -> void:
	toggle_button.toggled.connect(_on_toggled)
	toggle_button.icon = expanded_icon


func set_group_name(group_name: String) -> void:
	toggle_button.text = group_name


func _on_toggled(expanded: bool) -> void:
	list.visible = expanded
	toggle_button.icon = expanded_icon if expanded else collapsed_icon
	SFX.play(SFX.LD_SELECT if expanded else SFX.LD_BACK)
