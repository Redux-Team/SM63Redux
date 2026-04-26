class_name LDLayerPropertiesList
extends MarginContainer

@export var top_label: Label
@export var deco_layer: CheckBox
@export var parallax_slider_x: HSlider
@export var parallax_slider_y: HSlider
@export var parallax_label_x: Label
@export var parallax_label_y: Label
@export var modulate_color_picker: ColorPickerButton


func _ready() -> void:
	deco_layer.toggled.connect(_on_prop_changed)
	parallax_slider_x.value_changed.connect(_on_prop_changed)
	parallax_slider_y.value_changed.connect(_on_prop_changed)
	modulate_color_picker.color_changed.connect(_on_prop_changed)


func _on_show() -> void:
	var layer_index: int = LD.get_editor_viewport().get_active_layer()
	top_label.text = "Layer %s" % layer_index
	var layer: LDLayer = LD.get_editor_viewport().get_or_create_layer(layer_index)
	
	modulate_color_picker.color = layer.base_modulate
	
	deco_layer.button_pressed = layer.decoration
	
	parallax_slider_x.value = layer.parallax_scale.x
	parallax_label_x.text = "%.1fx" % layer.parallax_scale.x
	
	parallax_slider_y.value = layer.parallax_scale.y
	parallax_label_y.text = "%.1fx" % layer.parallax_scale.y


func _on_prop_changed(..._values: Array) -> void:
	var layer_index: int = LD.get_editor_viewport().get_active_layer()
	var layer: LDLayer = LD.get_editor_viewport().get_or_create_layer(layer_index)
	
	layer.base_modulate = modulate_color_picker.color
	
	layer.decoration = deco_layer.button_pressed
	
	layer.parallax_scale.x = parallax_slider_x.value
	parallax_label_x.text = "%.1fx" % layer.parallax_scale.x
	
	layer.parallax_scale.y = parallax_slider_y.value
	parallax_label_y.text = "%.1fx" % layer.parallax_scale.y
