class_name LDLayerNavigation
extends LDComponent

@export var previous_button: BaseButton
@export var next_button: BaseButton
@export var layer_label: Label


func _setup() -> void:
	var level: LDLevelHandler = editor.level_handler
	LD.bind_button(previous_button, level.step_layer.bind(-1))
	LD.bind_button(next_button, level.step_layer.bind(1))
	level.layer_changed.connect(_refresh.unbind(1))
	level.structure_changed.connect(_refresh)


func _refresh() -> void:
	var level: LDLevelHandler = editor.level_handler
	if level.active_layer == null:
		return
	
	var layers: Array[LevelLayer] = level.active_area.get_layers()
	layer_label.text = level.get_layer_label(level.active_layer)
	LD.set_disabled(previous_button, level.active_layer == layers.front())
	LD.set_disabled(next_button, level.active_layer == layers.back())
