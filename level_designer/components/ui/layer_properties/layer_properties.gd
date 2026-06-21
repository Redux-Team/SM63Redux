class_name LDLayerPropertiesList
extends MarginContainer

## Manages the active area's object layers: lists them (by name, or "Layer <i> (<n> objects)"),
## picks the active one, reorders their render depth, and edits the selected layer's properties.


const PICKER_SCALE: float = 0.8
const POPUP_PAD: int = 10
const ROW_CLASS: StringName = &"ListRow"
const LOCK_ICON: Texture2D = preload("res://assets/textures/level_designer/ui_icons/lock.svg")


@export var row_container: VBoxContainer
@export var add_button: Button
@export var move_up_button: Button
@export var move_down_button: Button
@export var remove_button: Button
@export var count_label: Label

@export var detail: VBoxContainer
@export var detail_rows: VBoxContainer
@export var blocked_label: Label
@export var name_edit: LineEdit
@export var deco_layer: CheckButton
@export var parallax_slider_x: HSlider
@export var parallax_slider_y: HSlider
@export var parallax_label_x: Label
@export var parallax_label_y: Label
@export var modulate_color_picker: ColorPickerButton


var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _setting_fields: bool = false


func _ready() -> void:
	add_button.pressed.connect(_on_add)
	move_up_button.pressed.connect(_on_move.bind(-1))
	move_down_button.pressed.connect(_on_move.bind(1))
	remove_button.pressed.connect(_on_remove)
	name_edit.text_changed.connect(_on_name_changed)
	deco_layer.toggled.connect(_on_prop_changed)
	parallax_slider_x.value_changed.connect(_on_prop_changed)
	parallax_slider_y.value_changed.connect(_on_prop_changed)
	modulate_color_picker.color_changed.connect(_on_prop_changed)
	_setup_color_picker()


func _setup_color_picker() -> void:
	var picker: ColorPicker = modulate_color_picker.get_picker()
	picker.presets_visible = false
	picker.sampler_visible = false
	picker.color_modes_visible = false
	picker.edit_intensity = false
	var popup: PopupPanel = modulate_color_picker.get_popup()
	popup.content_scale_factor = PICKER_SCALE
	popup.add_theme_stylebox_override(&"panel", _make_popup_panel())
	popup.about_to_popup.connect(_fit_color_popup)
	picker.minimum_size_changed.connect(_fit_color_popup)


func _make_popup_panel() -> StyleBoxFlat:
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color("#1c2332e6")
	panel.border_color = Color("#54658c")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(POPUP_PAD)
	return panel


func _fit_color_popup() -> void:
	var picker: ColorPicker = modulate_color_picker.get_picker()
	var pad: float = POPUP_PAD * 2.0
	var target: Vector2 = (picker.get_combined_minimum_size() + Vector2(pad, pad)) * PICKER_SCALE
	modulate_color_picker.get_popup().size = Vector2i(target.ceil())


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
	_clear_rows()
	var selected: int = -1
	for i: int in area.layers.size():
		var layer: LDLayer = area.layers[i]
		var row: Button = _make_row(_label(layer, anchor), layer.index == anchor)
		row_container.add_child(row)
		row.pressed.connect(_on_row_pressed.bind(i))
		_rows.append(row)
		if layer.index == active:
			selected = i
	if selected >= 0:
		_rows[selected].button_pressed = true
	_setting_fields = false
	_show_detail(selected)


func _make_row(text: String, locked: bool) -> Button:
	var row: Button = Button.new()
	row.text = text
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.set_meta(&"gdss_classes", PackedStringArray([ROW_CLASS]))
	if locked:
		var lock: TextureRect = TextureRect.new()
		lock.texture = LOCK_ICON
		lock.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lock.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		lock.mouse_filter = Control.MOUSE_FILTER_IGNORE
		lock.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
		lock.offset_left = -24.0
		lock.offset_top = -7.0
		lock.offset_right = -10.0
		lock.offset_bottom = 7.0
		row.add_child(lock)
	return row


func _clear_rows() -> void:
	for row: Button in _rows:
		row.button_group = null
		row.queue_free()
	_rows.clear()


## Unnamed layers are numbered relative to the player's layer (the anchor), so the player's layer
## reads as "Layer 0" and the others as their depth offset from it.
func _label(layer: LDLayer, anchor: int) -> String:
	if not layer.layer_name.is_empty():
		return layer.layer_name
	return "Layer %d" % (layer.index - anchor)


func _selected_index() -> int:
	for i: int in _rows.size():
		if _rows[i].button_pressed:
			return i
	return -1


func _selected_layer() -> LDLayer:
	var idx: int = _selected_index()
	if idx < 0:
		return null
	return _area().layers[idx]


func _on_row_pressed(pos: int) -> void:
	if _setting_fields:
		return
	# Read the target before switching: set_active_layer may drop the previous (empty, unnamed) one.
	var target: int = _area().layers[pos].index
	LD.get_editor_viewport().navigate_active_layer(target)
	_refresh()


func _on_add() -> void:
	var current: LDLayer = _selected_layer()
	if current:
		_area().add_layer_below(current)
	else:
		_area().add_layer()
	_refresh()


func _on_move(delta: int) -> void:
	var layer: LDLayer = _selected_layer()
	if not layer:
		return
	_area().move_layer_order(layer, delta)
	_refresh()


func _on_remove() -> void:
	var layer: LDLayer = _selected_layer()
	if not layer:
		return
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
	var pos: int = _area().layers.find(layer)
	_area().remove_layer(layer)
	var remaining: Array[LDLayer] = _area().layers
	if not remaining.is_empty():
		var target: LDLayer = remaining[clampi(pos - 1, 0, remaining.size() - 1)]
		LD.get_editor_viewport().navigate_active_layer(target.index)
	_refresh()

#endregion


#region Detail

func _show_detail(pos: int) -> void:
	var has_layer: bool = pos >= 0
	detail.visible = has_layer
	if has_layer:
		var count: int = _area().layers[pos].get_objects_root().get_child_count()
		var noun: String = "object" if count == 1 else "objects"
		count_label.text = "%d %s" % [count, noun]
	else:
		count_label.text = ""
	move_up_button.disabled = not has_layer or pos == 0
	GDSS.refresh(move_up_button)
	move_down_button.disabled = not has_layer or pos >= _area().layers.size() - 1
	GDSS.refresh(move_down_button)
	if not has_layer:
		remove_button.disabled = true
		GDSS.refresh(remove_button)
		return
	
	var layer: LDLayer = _area().layers[pos]
	var locked: bool = layer.index == _area().get_player_layer_index()
	detail_rows.visible = not locked
	blocked_label.visible = locked
	remove_button.disabled = locked
	GDSS.refresh(remove_button)
	if locked:
		return
	
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
	var idx: int = _selected_index()
	if idx < 0:
		return
	var layer: LDLayer = _area().layers[idx]
	_area().set_layer_name(layer, LDText.sanitize_edit(name_edit))
	_rows[idx].text = _label(layer, _area().get_player_layer_index())


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
