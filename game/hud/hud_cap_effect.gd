class_name HUDCapEffect
extends Node

@export var cap: StringName
@export var targets: Array[CanvasItem] = []
@export var material: ShaderMaterial
@export var parameter: StringName = &"progress"
@export var indicators: Array[CanvasItem] = []

var _cap_mode: CapMode
var _base_materials: Dictionary[CanvasItem, Material] = {}


func _ready() -> void:
	set_process(false)
	_show_indicators(false)


func bind(caps: MultiModeMachine) -> void:
	_cap_mode = caps.get_mode(cap) as CapMode
	for target: CanvasItem in targets:
		_base_materials.set(target, target.material)
	
	caps.mode_started.connect(_on_mode_started)
	caps.mode_stopped.connect(_on_mode_stopped)
	if caps.is_running(cap):
		_on_mode_started(_cap_mode)


func _process(_delta: float) -> void:
	_set_progress(_cap_mode.get_remaining_ratio())


func _set_progress(value: float) -> void:
	for target: CanvasItem in targets:
		(target.material as ShaderMaterial).set_shader_parameter(parameter, value)


func _show_indicators(shown: bool) -> void:
	for indicator: CanvasItem in indicators:
		indicator.visible = shown


func _on_mode_started(mode: Mode) -> void:
	if mode != _cap_mode:
		return
	
	if material:
		for target: CanvasItem in targets:
			target.material = material
	_show_indicators(true)
	set_process(true)
	_process(0.0)


func _on_mode_stopped(mode: Mode) -> void:
	if mode != _cap_mode:
		return
	
	if material:
		for target: CanvasItem in targets:
			target.material = _base_materials.get(target)
	else:
		_set_progress(0.0)
	_show_indicators(false)
	set_process(false)
