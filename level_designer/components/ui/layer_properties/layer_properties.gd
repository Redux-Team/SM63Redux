class_name LDLayerPropertiesList
extends MarginContainer

## Manages the active area's object layers: lists them (by name, or "Layer <i> (<n> objects)"),
## picks the active one, reorders their render depth, and edits the selected layer's properties.


@export var layer_list: ItemList
@export var add_above_button: Button
@export var add_below_button: Button
@export var move_up_button: Button
@export var move_down_button: Button
@export var remove_button: Button

@export var detail: VBoxContainer
@export var name_edit: LineEdit
@export var deco_layer: CheckButton
@export var parallax_slider_x: HSlider
@export var parallax_slider_y: HSlider
@export var parallax_label_x: Label
@export var parallax_label_y: Label
@export var modulate_color_picker: ColorPickerButton


var _setting_fields: bool = false


func _ready() -> void:
	layer_list.item_selected.connect(_on_layer_selected)
	add_above_button.pressed.connect(_on_add.bind(true))
	add_below_button.pressed.connect(_on_add.bind(false))
	move_up_button.pressed.connect(_on_move.bind(-1))
	move_down_button.pressed.connect(_on_move.bind(1))
	remove_button.pressed.connect(_on_remove)
	name_edit.text_changed.connect(_on_name_changed)
	deco_layer.toggled.connect(_on_prop_changed)
	parallax_slider_x.value_changed.connect(_on_prop_changed)
	parallax_slider_y.value_changed.connect(_on_prop_changed)
	modulate_color_picker.color_changed.connect(_on_prop_changed)


func _on_show() -> void:
	_refresh()


func _area() -> LDArea:
	return LDLevel.get_active_area()


#region List

func _refresh() -> void:
	var area: LDArea = _area()
	var active: int = area.get_active_layer_index()
	var anchor: int = area.get_player_layer_index()
	_setting_fields = true
	layer_list.clear()
	var selected: int = -1
	for i: int in area.layers.size():
		var layer: LDLayer = area.layers[i]
		layer_list.add_item(_label(layer, anchor))
		if layer.index == active:
			selected = i
	if selected >= 0:
		layer_list.select(selected)
	_setting_fields = false
	_show_detail(selected)


## Unnamed layers are numbered relative to the player's layer (the anchor), so the player's layer
## reads as "Layer 0" and the others as their depth offset from it.
func _label(layer: LDLayer, anchor: int) -> String:
	if not layer.layer_name.is_empty():
		return layer.layer_name
	return "Layer %d (%d objects)" % [layer.index - anchor, layer.get_objects_root().get_child_count()]


func _selected_layer() -> LDLayer:
	var sel: PackedInt32Array = layer_list.get_selected_items()
	if sel.is_empty():
		return null
	return _area().layers[sel[0]]


func _on_layer_selected(pos: int) -> void:
	if _setting_fields:
		return
	# Read the target before switching: set_active_layer may drop the previous (empty, unnamed) one.
	var target: int = _area().layers[pos].index
	LD.get_editor_viewport().navigate_active_layer(target)
	_refresh()


func _on_add(above: bool) -> void:
	var current: LDLayer = _selected_layer()
	if not current:
		_area().add_layer()
	elif above:
		_area().add_layer_above(current)
	else:
		_area().add_layer_below(current)
	_refresh()


func _on_move(delta: int) -> void:
	var layer: LDLayer = _selected_layer()
	if not layer:
		return
	_area().move_layer_order(layer, delta)
	_refresh()


func _on_remove() -> void:
	var sel: PackedInt32Array = layer_list.get_selected_items()
	if sel.is_empty():
		return
	var layer: LDLayer = _area().layers[sel[0]]
	if layer.is_empty():
		_remove(layer)
		return
	# Layer has objects: confirm before discarding them.
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Remove Layer"
	dialog.dialog_text = "Remove \"%s\" and its %d object(s)?" % [_label(layer, _area().get_player_layer_index()), layer.get_objects_root().get_child_count()]
	dialog.confirmed.connect(func() -> void: _remove(layer))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()


func _remove(layer: LDLayer) -> void:
	_area().remove_layer(layer)
	_refresh()

#endregion


#region Detail

func _show_detail(pos: int) -> void:
	var has_layer: bool = pos >= 0
	detail.visible = has_layer
	move_up_button.disabled = not has_layer or pos == 0
	move_down_button.disabled = not has_layer or pos >= _area().layers.size() - 1
	if not has_layer:
		remove_button.disabled = true
		return

	remove_button.disabled = false
	var layer: LDLayer = _area().layers[pos]
	_setting_fields = true
	name_edit.text = layer.layer_name
	deco_layer.button_pressed = layer.is_decoration
	parallax_slider_x.value = layer.parallax_scale.x
	parallax_label_x.text = "%.1fx" % layer.parallax_scale.x
	parallax_slider_y.value = layer.parallax_scale.y
	parallax_label_y.text = "%.1fx" % layer.parallax_scale.y
	modulate_color_picker.color = layer.modulation
	_setting_fields = false


func _on_name_changed(_text: String) -> void:
	if _setting_fields:
		return
	var sel: PackedInt32Array = layer_list.get_selected_items()
	if sel.is_empty():
		return
	var layer: LDLayer = _area().layers[sel[0]]
	_area().set_layer_name(layer, LDText.sanitize_edit(name_edit))
	layer_list.set_item_text(sel[0], _label(layer, _area().get_player_layer_index()))


func _on_prop_changed(_value: Variant = null) -> void:
	if _setting_fields:
		return
	var layer: LDLayer = _area().get_active_layer()
	layer.modulation = modulate_color_picker.color
	layer.is_decoration = deco_layer.button_pressed
	layer.parallax_scale.x = parallax_slider_x.value
	parallax_label_x.text = "%.1fx" % layer.parallax_scale.x
	layer.parallax_scale.y = parallax_slider_y.value
	parallax_label_y.text = "%.1fx" % layer.parallax_scale.y

#endregion
