class_name LDBackgroundEditor
extends MarginContainer

## Editor for the level's background. A background is picked from a list of presets; choosing
## "Custom" (or editing anything) unlocks the backdrop and per-layer controls, which write straight
## to LDBackgroundHandler. The handler rebuilds the live viewport background and persists it.


const ROW_CLASS: StringName = &"ListRow"
const BACKDROP_ROW: int = 0
const PICKER_SCALE: float = 0.8
const POPUP_PAD: int = 10


@export var preset_option: OptionButton

@export var row_container: VBoxContainer
@export var add_layer_button: Button
@export var move_up_button: Button
@export var move_down_button: Button
@export var remove_layer_button: Button
@export var empty_center: Control

@export var backdrop_content: Control
@export var type_option: OptionButton
@export var solid_row: HBoxContainer
@export var solid_color: ColorPickerButton
@export var gradient_rows: VBoxContainer
@export var gradient_top: ColorPickerButton
@export var gradient_bottom: ColorPickerButton
@export var backdrop_preview: TextureRect

@export var layer_content: Control
@export var layer_preview: TextureRect
@export var texture_option: OptionButton
@export var parallax_spin: SpinBox
@export var custom_color_check: CheckButton
@export var color_picker: ColorPickerButton
@export var offset_x: SpinBox
@export var offset_y: SpinBox
@export var autoscroll_x: SpinBox
@export var autoscroll_y: SpinBox


var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _selected_row: int = -1
var _setting_fields: bool = false


func _ready() -> void:
	preset_option.item_selected.connect(_on_preset_selected)
	
	type_option.add_item("Solid", LDBackground.Backdrop.SOLID)
	type_option.add_item("Gradient", LDBackground.Backdrop.GRADIENT)
	type_option.item_selected.connect(_on_type_selected)
	
	solid_color.color_changed.connect(func(c: Color) -> void:
		_commit(_handler().set_solid_color.bind(c))
		_update_backdrop_preview()
	)
	gradient_top.color_changed.connect(func(c: Color) -> void:
		_commit(_handler().set_gradient_top.bind(c))
		_update_backdrop_preview()
	)
	gradient_bottom.color_changed.connect(func(c: Color) -> void:
		_commit(_handler().set_gradient_bottom.bind(c))
		_update_backdrop_preview()
	)
	
	add_layer_button.pressed.connect(_on_add_layer)
	move_up_button.pressed.connect(_on_move_layer.bind(-1))
	move_down_button.pressed.connect(_on_move_layer.bind(1))
	remove_layer_button.pressed.connect(_on_remove_layer)
	
	texture_option.item_selected.connect(_on_texture_selected)
	parallax_spin.value_changed.connect(func(v: float) -> void: _set_field("parallax", v))
	custom_color_check.toggled.connect(_on_custom_color_toggled)
	# Both pickers edit the layer's modulate; in custom-color mode it is the grayscale tint, otherwise
	# a plain multiply.
	color_picker.color_changed.connect(func(c: Color) -> void: _set_field("modulate", c))
	# Offset Y is shown flipped (negative = down) so it reads intuitively; storage keeps Godot's
	# +y-down convention, so negate on the way in and out.
	offset_x.value_changed.connect(func(_v: float) -> void: _set_field("offset", Vector2(offset_x.value, -offset_y.value)))
	offset_y.value_changed.connect(func(_v: float) -> void: _set_field("offset", Vector2(offset_x.value, -offset_y.value)))
	autoscroll_x.value_changed.connect(func(_v: float) -> void: _set_field("autoscroll", Vector2(autoscroll_x.value, autoscroll_y.value)))
	autoscroll_y.value_changed.connect(func(_v: float) -> void: _set_field("autoscroll", Vector2(autoscroll_x.value, autoscroll_y.value)))
	
	_setup_color_pickers()
	_populate_texture_option()


func _setup_color_pickers() -> void:
	for button: ColorPickerButton in [solid_color, gradient_top, gradient_bottom, color_picker]:
		var picker: ColorPicker = button.get_picker()
		picker.presets_visible = false
		picker.sampler_visible = false
		picker.color_modes_visible = false
		picker.edit_intensity = false
		var popup: PopupPanel = button.get_popup()
		popup.content_scale_factor = PICKER_SCALE
		popup.add_theme_stylebox_override(&"panel", _make_popup_panel())
		popup.about_to_popup.connect(_fit_color_popup.bind(button))
		picker.minimum_size_changed.connect(_fit_color_popup.bind(button))


func _make_popup_panel() -> StyleBoxFlat:
	var panel: StyleBoxFlat = StyleBoxFlat.new()
	panel.bg_color = Color("#1c2332e6")
	panel.border_color = Color("#54658c")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(12)
	panel.set_content_margin_all(POPUP_PAD)
	return panel


func _fit_color_popup(button: ColorPickerButton) -> void:
	var picker: ColorPicker = button.get_picker()
	var pad: float = POPUP_PAD * 2.0
	var target: Vector2 = (picker.get_combined_minimum_size() + Vector2(pad, pad)) * PICKER_SCALE
	button.get_popup().size = Vector2i(target.ceil())


func _on_show() -> void:
	# Repopulate here (not just in _ready): presets and texture uids are only ready once the
	# background handler has run, which can be after this editor's _ready.
	_populate_presets()
	_populate_texture_option()
	_refresh()


func _handler() -> LDBackgroundHandler:
	return LD.get_background_handler()


func _commit(action: Callable) -> void:
	if _setting_fields:
		return
	action.call()
	_select_active_preset()


#region Presets

func _populate_presets() -> void:
	preset_option.clear()
	for preset_name: String in _handler().get_preset_names():
		preset_option.add_item(preset_name)
	preset_option.add_item(LDBackgroundDB.CUSTOM)


func _on_preset_selected(index: int) -> void:
	if _setting_fields:
		return
	_selected_row = BACKDROP_ROW
	_handler().select_preset(preset_option.get_item_text(index))
	_refresh()


func _select_active_preset() -> void:
	var active: String = _handler().get_active_preset()
	for i: int in preset_option.item_count:
		if preset_option.get_item_text(i) == active:
			preset_option.select(i)
			return


#endregion


#region List

func _refresh() -> void:
	var bg: LDBackground = _handler().get_background()
	_setting_fields = true
	_select_active_preset()
	for i: int in type_option.item_count:
		if type_option.get_item_id(i) == bg.backdrop_type:
			type_option.select(i)
	solid_color.color = bg.solid_color
	gradient_top.color = bg.gradient_top
	gradient_bottom.color = bg.gradient_bottom
	_setting_fields = false
	
	_build_rows()
	
	var target: int = _selected_row
	if target < 0 or target >= _rows.size():
		target = BACKDROP_ROW
	if target < _rows.size():
		_rows[target].button_pressed = true
		_show_detail(target)
	else:
		_show_detail(-1)


func _build_rows() -> void:
	_clear_rows()
	_add_row("Backdrop")
	var layers: Array[LDBackgroundLayer] = _handler().get_background().layers
	for i: int in layers.size():
		_add_row(_layer_label(layers[i], i))


func _add_row(text: String) -> void:
	var row: Button = Button.new()
	row.text = text
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.set_meta(&"gdss_classes", PackedStringArray([ROW_CLASS]))
	var row_index: int = _rows.size()
	row_container.add_child(row)
	row.pressed.connect(_on_row_pressed.bind(row_index))
	_rows.append(row)


func _clear_rows() -> void:
	for row: Button in _rows:
		row.button_group = null
		row_container.remove_child(row)
		row.queue_free()
	_rows.clear()


func _on_row_pressed(row: int) -> void:
	_show_detail(row)


func _show_detail(row: int) -> void:
	_selected_row = row
	var is_backdrop: bool = row == BACKDROP_ROW
	var is_layer: bool = row > BACKDROP_ROW
	empty_center.visible = row < 0
	backdrop_content.visible = is_backdrop
	layer_content.visible = is_layer
	_select_active_preset()
	_update_layer_buttons()
	if is_backdrop:
		_update_backdrop_rows(_handler().get_background().backdrop_type)
	elif is_layer:
		_show_layer_fields(row - 1)

#endregion


#region Backdrop

func _on_type_selected(index: int) -> void:
	var type: int = type_option.get_item_id(index)
	_commit(_handler().set_backdrop_type.bind(type))
	_update_backdrop_rows(type)


func _update_backdrop_rows(type: int) -> void:
	solid_row.visible = type == LDBackground.Backdrop.SOLID
	gradient_rows.visible = type == LDBackground.Backdrop.GRADIENT
	_update_backdrop_preview()


## Shows the current backdrop in the preview, mirroring LDBackground._build_backdrop(): a vertical
## gradient, or a flat fill for a solid color (both gradient stops set to it).
func _update_backdrop_preview() -> void:
	var bg: LDBackground = _handler().get_background()
	var gradient: Gradient = Gradient.new()
	if bg.backdrop_type == LDBackground.Backdrop.GRADIENT:
		gradient.set_color(0, bg.gradient_bottom)
		gradient.set_color(1, bg.gradient_top)
	else:
		gradient.set_color(0, bg.solid_color)
		gradient.set_color(1, bg.solid_color)
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = gradient
	tex.width = 1
	tex.height = 128
	tex.fill_from = Vector2(0.0, 1.0)
	tex.fill_to = Vector2(0.0, 0.0)
	backdrop_preview.texture = tex

#endregion


#region Layers

func _populate_texture_option() -> void:
	texture_option.clear()
	for preset: LDBackgroundLayer in _handler().get_available_layers():
		texture_option.add_item(preset.display_name)
		texture_option.set_item_metadata(texture_option.item_count - 1, preset)


## Names a layer by its preset's display name (multiple layers may share one). When the layer has no
## stored name (e.g. it came from a preset background), match a layer preset by texture; falls back
## to the texture file name, then the index.
func _layer_label(layer: LDBackgroundLayer, index: int) -> String:
	if not layer.display_name.is_empty():
		return layer.display_name
	if layer.texture:
		for preset: LDBackgroundLayer in _handler().get_available_layers():
			if preset.texture == layer.texture:
				return preset.display_name
		if not layer.texture.resource_path.is_empty():
			return layer.texture.resource_path.get_file().get_basename()
	return "Layer %d" % index


func _on_add_layer() -> void:
	_handler().add_layer()
	_build_rows()
	var new_row: int = _handler().get_background().layers.size()
	if new_row < _rows.size():
		_rows[new_row].button_pressed = true
		_show_detail(new_row)


func _on_move_layer(delta: int) -> void:
	if _selected_row <= BACKDROP_ROW:
		return
	var new_layer: int = _handler().move_layer(_selected_row - 1, delta)
	_build_rows()
	var new_row: int = new_layer + 1
	if new_row < _rows.size():
		_rows[new_row].button_pressed = true
		_show_detail(new_row)


func _on_remove_layer() -> void:
	if _selected_row <= BACKDROP_ROW:
		return
	var removed: int = _selected_row - 1
	_handler().remove_layer(removed)
	_build_rows()
	# Select the layer that shifted into the removed slot (or the previous one); fall back to Backdrop.
	var remaining: int = _handler().get_background().layers.size()
	var target: int = BACKDROP_ROW
	if remaining > 0:
		target = mini(removed, remaining - 1) + 1
	if target < _rows.size():
		_rows[target].button_pressed = true
		_show_detail(target)


## Enables the move/remove buttons against the current selection (presets are editable too, so this
## no longer gates on custom).
func _update_layer_buttons() -> void:
	var count: int = _handler().get_background().layers.size()
	var layer: int = _selected_row - 1
	var has_layer: bool = _selected_row > BACKDROP_ROW
	remove_layer_button.disabled = not has_layer
	GDSS.refresh(remove_layer_button)
	move_up_button.disabled = not has_layer or layer <= 0
	GDSS.refresh(move_up_button)
	move_down_button.disabled = not has_layer or layer >= count - 1
	GDSS.refresh(move_down_button)


func _show_layer_fields(index: int) -> void:
	var layer: LDBackgroundLayer = _handler().get_background().layers[index]
	_setting_fields = true
	for i: int in texture_option.item_count:
		var preset: LDBackgroundLayer = texture_option.get_item_metadata(i)
		if preset and preset.id == layer.id:
			texture_option.select(i)
	parallax_spin.value = layer.parallax
	custom_color_check.button_pressed = layer.custom_color
	# The same modulate drives both pickers; only one row is shown at a time.
	color_picker.color = layer.modulate
	offset_x.value = layer.offset.x
	offset_y.value = -layer.offset.y
	autoscroll_x.value = layer.autoscroll.x
	autoscroll_y.value = layer.autoscroll.y
	_setting_fields = false
	_update_color_rows()
	_update_preview()


## Mirrors build_into()'s per-layer look in the detail preview: a plain modulate, or the grayscale
## tint shader when custom color is on.
func _update_preview() -> void:
	if _selected_row <= BACKDROP_ROW:
		return
	var layer: LDBackgroundLayer = _handler().get_background().layers[_selected_row - 1]
	layer_preview.texture = layer.texture
	if not layer.texture:
		layer_preview.material = null
		return
	if layer.custom_color:
		var mat: ShaderMaterial = layer_preview.material as ShaderMaterial
		if not mat:
			mat = ShaderMaterial.new()
			mat.shader = LDBackground.TINT_SHADER
			layer_preview.material = mat
		mat.set_shader_parameter(&"tint_color", layer.modulate)
		layer_preview.modulate = Color.WHITE
	else:
		layer_preview.material = null
		layer_preview.modulate = layer.modulate


## Custom color desaturates the layer and tints it by the picker; turning it off clears the tint to white.
func _on_custom_color_toggled(on: bool) -> void:
	if not on and not _setting_fields and _selected_row > BACKDROP_ROW:
		_setting_fields = true
		color_picker.color = Color.WHITE
		_setting_fields = false
		_set_field("modulate", Color.WHITE)
	_set_field("custom_color", on)
	_update_color_rows()


func _update_color_rows() -> void:
	color_picker.visible = custom_color_check.button_pressed


## Picking a layer preset swaps the layer to that preset's texture + defaults (incl. the correct
## anchor), keeping the user's colour. Rebuilds the row (its label may change) and reloads the fields.
func _on_texture_selected(index: int) -> void:
	if _setting_fields or _selected_row <= BACKDROP_ROW:
		return
	var layer: int = _selected_row - 1
	_handler().set_layer_preset(layer, texture_option.get_item_metadata(index))
	_build_rows()
	var row: int = layer + 1
	if row < _rows.size():
		_rows[row].button_pressed = true
		_show_detail(row)


func _set_field(key: String, value: Variant) -> void:
	if _setting_fields or _selected_row <= BACKDROP_ROW:
		return
	_handler().set_layer_field(_selected_row - 1, key, value)
	_select_active_preset()
	_update_preview()

#endregion
