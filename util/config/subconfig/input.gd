@tool
class_name InputConfig
extends Subconfig

@export_group("Controls")
@export var default_control_scheme: ControlScheme
@export var control_schemes: Array[ControlScheme]
@export var selected_control_scheme: int = -1

@export_group("Touch Controls")
@export var button_map: Dictionary[StringName, TouchButtonSetting]
@export_range(0, 100) var button_opacity: float = 70.0
@export_range(0.25, 3.0) var button_scale: float = 1.0
@export var touch_scene: PackedScene
@export var default_touch_scene: PackedScene

@export_group("Controller", "controller_")
@export var controller_icon_map: Dictionary[InputEvent, Texture2D]


func get_active_control_scheme() -> ControlScheme:
	if selected_control_scheme == -1:
		control_schemes.append(ControlScheme.copy_from(default_control_scheme))
		selected_control_scheme = 0
	
	return control_schemes[selected_control_scheme]
