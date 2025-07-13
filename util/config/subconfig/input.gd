@tool
class_name InputConfig
extends Subconfig

@export_group("Touch Controls")
@export_range(0, 100) var button_opacity: float = 70.0
@export_range(0.25, 3.0) var button_scale: float = 1.0

@export_group("Control Schemes")
@export var default_control_scheme: ControlScheme
@export var control_schemes: Array[ControlScheme]
@export var control_scheme_index: int = -1:
	set(ccs):
		control_scheme_index = clamp(ccs, -1, control_schemes.size())

var current_control_scheme: ControlScheme
