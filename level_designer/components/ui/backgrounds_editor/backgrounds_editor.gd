class_name LDBackgroundEditor
extends MarginContainer

## Editor for the level's background. A background is picked from a list of presets; choosing
## "Custom" (or editing anything) unlocks the backdrop and per-layer controls, which write straight
## to LDBackgroundHandler. The handler rebuilds the live viewport background and persists it.


@export var preset_option: OptionButton

@export var type_option: OptionButton
@export var solid_row: HBoxContainer
@export var solid_color: ColorPickerButton
@export var gradient_rows: VBoxContainer
@export var gradient_top: ColorPickerButton
@export var gradient_bottom: ColorPickerButton
@export var backdrop_preview: TextureRect

@export var layer_list: ItemList
@export var add_layer_button: Button
@export var move_up_button: Button
@export var move_down_button: Button
@export var remove_layer_button: Button
@export var layer_placeholder: Label
@export var layer_preview: TextureRect
@export var layer_fields: VBoxContainer
@export var texture_option: OptionButton
@export var parallax_spin: SpinBox
@export var custom_color_check: CheckButton
@export var color_picker: ColorPickerButton
@export var offset_x: SpinBox
@export var offset_y: SpinBox
@export var autoscroll_x: SpinBox
@export var autoscroll_y: SpinBox


var _selected_layer: int = -1
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
	layer_list.item_selected.connect(_on_layer_selected)

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

	_populate_texture_option()
	_refresh()


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


#region Presets

func _populate_presets() -> void:
	preset_option.clear()
	for preset_name: String in _handler().get_preset_names():
		preset_option.add_item(preset_name)
	preset_option.add_item(LDBackgroundDB.CUSTOM)


func _on_preset_selected(index: int) -> void:
	if _setting_fields:
		return
	_selected_layer = -1
	_handler().select_preset(preset_option.get_item_text(index))
	_refresh()


func _select_active_preset() -> void:
	var active: String = _handler().get_active_preset()
	for i: int in preset_option.item_count:
		if preset_option.get_item_text(i) == active:
			preset_option.select(i)
			return


func _update_editability() -> void:
	var custom: bool = _handler().is_custom()
	type_option.disabled = not custom
	solid_color.disabled = not custom
	gradient_top.disabled = not custom
	gradient_bottom.disabled = not custom
	add_layer_button.disabled = not custom
	_update_layer_buttons()
	texture_option.disabled = not custom
	parallax_spin.editable = custom
	custom_color_check.disabled = not custom
	color_picker.disabled = not custom
	offset_x.editable = custom
	offset_y.editable = custom
	autoscroll_x.editable = custom
	autoscroll_y.editable = custom

#endregion


#region Backdrop

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
	_update_backdrop_rows(bg.backdrop_type)
	_refresh_layer_list()
	_update_editability()


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
	for tex: Texture2D in _handler().get_available_textures():
		texture_option.add_item(tex.resource_path.get_file().get_basename())
		texture_option.set_item_metadata(texture_option.item_count - 1, tex)


func _refresh_layer_list() -> void:
	var prev: int = _selected_layer
	var layers: Array[LDBackgroundLayer] = _handler().get_background().layers
	layer_list.clear()
	for i: int in layers.size():
		layer_list.add_item(_layer_label(layers[i], i))
	if prev >= 0 and prev < layer_list.item_count:
		layer_list.select(prev)
		_show_layer_detail(prev)
	else:
		_show_layer_detail(-1)


## Names a layer by its texture (multiple layers may share a name); falls back to its index.
func _layer_label(layer: LDBackgroundLayer, index: int) -> String:
	if layer.texture and not layer.texture.resource_path.is_empty():
		return layer.texture.resource_path.get_file().get_basename()
	return "Layer %d" % index


func _on_add_layer() -> void:
	_handler().add_layer()
	var index: int = _handler().get_background().layers.size() - 1
	_refresh_layer_list()
	layer_list.select(index)
	_show_layer_detail(index)


func _on_move_layer(delta: int) -> void:
	if _selected_layer < 0:
		return
	_selected_layer = _handler().move_layer(_selected_layer, delta)
	_refresh_layer_list()
	layer_list.select(_selected_layer)
	_show_layer_detail(_selected_layer)


func _on_remove_layer() -> void:
	if _selected_layer < 0:
		return
	_handler().remove_layer(_selected_layer)
	_selected_layer = -1
	_refresh_layer_list()


func _on_layer_selected(index: int) -> void:
	_show_layer_detail(index)


## Enables the move/remove buttons against the current selection and custom state. Kept separate from
## _update_editability so selecting a layer (which doesn't rerun it) still updates them.
func _update_layer_buttons() -> void:
	var custom: bool = _handler().is_custom()
	var count: int = _handler().get_background().layers.size()
	remove_layer_button.disabled = not custom or _selected_layer < 0
	move_up_button.disabled = not custom or _selected_layer <= 0
	move_down_button.disabled = not custom or _selected_layer < 0 or _selected_layer >= count - 1


func _show_layer_detail(index: int) -> void:
	_selected_layer = index
	var has_layer: bool = index >= 0
	# The detail column stays visible; swap between the preview + fields and a "select a layer" prompt.
	layer_fields.visible = has_layer
	layer_preview.visible = has_layer
	layer_placeholder.visible = not has_layer
	_update_layer_buttons()
	if not has_layer:
		return

	var layer: LDBackgroundLayer = _handler().get_background().layers[index]
	_setting_fields = true
	for i: int in texture_option.item_count:
		if texture_option.get_item_metadata(i) == layer.texture:
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
	if _selected_layer < 0:
		layer_preview.visible = false
		return
	var layer: LDBackgroundLayer = _handler().get_background().layers[_selected_layer]
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


## When custom color is on, the texture is grayscaled and tinted by the Color picker, so the plain
## Modulate row is hidden in favor of the Color row (and vice versa).
func _on_custom_color_toggled(on: bool) -> void:
	_set_field("custom_color", on)
	_update_color_rows()


func _update_color_rows() -> void:
	var custom: bool = custom_color_check.button_pressed
	color_picker.visible = custom


func _on_texture_selected(index: int) -> void:
	_set_field("texture", texture_option.get_item_metadata(index))


func _set_field(key: String, value: Variant) -> void:
	if _setting_fields or _selected_layer < 0:
		return
	_handler().set_layer_field(_selected_layer, key, value)
	_update_preview()

#endregion
