class_name LDBackgroundPanel
extends LDPanel

const ROW_CLASS: String = "ListRow"
const INDENT: int = 14
const TEXTURE_ROOT: String = "res://assets/textures/world/background/"
const HIDDEN: Array[StringName] = [&"layers", &"limited", &"limit", &"scroll_offset"]
const OPTION_WIDTH: float = 110.0
const DISABLED_ALPHA: float = 0.45
const DROP_EDGE: float = 0.3
const MARKER_COLOR: Color = Color("#6496ed")
const LABELS: Dictionary[StringName, String] = {
	&"layer_name": "Name",
	&"scroll_rate": "Parallax",
	&"scroll_offset": "Offset",
	&"texture_scale": "Scale",
	&"stretch_mode": "Stretch",
	&"flip_h": "Flip X",
	&"flip_v": "Flip Y",
	&"anchor_ratio": "Anchor Point",
	&"edge_extend": "Extend Edges",
	&"repeat_mode": "Repeat",
	&"repeat_amount": "Repeat Count",
	&"mirror": "Mirror Tiles",
}
const SECTIONS: Dictionary[StringName, String] = {
	&"layer_name": "Layer",
	&"enabled": "Layer",
	&"modulate": "Layer",
	&"texture": "Layer",
	&"anchor": "Position",
	&"anchor_offset": "Position",
	&"texture_scale": "Position",
	&"offset": "Position",
	&"scroll_rate": "Motion",
	&"autoscroll": "Motion",
	&"repeat_mode": "Motion",
}
const RANGES: Dictionary[StringName, Array] = {
	&"anchor_offset": ["-256,256,1", "%.0f"],
	&"offset": ["-256,256,1", "%.0f"],
	&"texture_scale": ["0.25,4,0.05", "%.2fx"],
	&"scroll_rate": ["0,1,0.01", "%.2f"],
	&"autoscroll": ["-64,64,1", "%.0f"],
	&"anchor_ratio": ["0,1,0.01", "%.2f"],
	&"spacing": ["-128,128,1", "%.0f"],
	&"repeat_amount": ["0,16,1", "%.0f"],
}
const SECTION_ORDER: PackedStringArray = ["Sky", "Layer", "Position", "Motion", "Advanced"]
const COLLAPSED: PackedStringArray = ["Advanced"]

@export var preset_option: OptionButton
@export var row_container: VBoxContainer
@export var add_button: BaseButton
@export var add_group_button: BaseButton
@export var duplicate_button: BaseButton
@export var move_up_button: BaseButton
@export var move_down_button: BaseButton
@export var remove_button: BaseButton
@export var detail_container: VBoxContainer
@export var section_scene: PackedScene
@export var group_icon: Texture2D
@export var group_open_icon: Texture2D

var _data: Dictionary = {}
var _layers: Array[BackgroundLayer] = []
var _selection: PackedInt32Array = PackedInt32Array()
var _open_groups: Array[PackedInt32Array] = []
var _revealed: PackedInt32Array = PackedInt32Array()
var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _bindings: Array[PropertyBinding] = []
var _signature: String = ""
var _expanded: Dictionary[String, bool] = {}
var _marker: ColorRect


func _setup() -> void:
	super()
	var level: LDLevelHandler = editor.level_handler
	level.background_changed.connect(_refresh.unbind(1))
	level.area_changed.connect(_on_area_changed.unbind(1))
	preset_option.item_selected.connect(_on_preset_selected)
	add_button.pressed.connect(_insert.bind(BackgroundLayer2D))
	add_group_button.pressed.connect(_on_group_pressed)
	duplicate_button.pressed.connect(_duplicate)
	move_up_button.pressed.connect(_move.bind(-1))
	move_down_button.pressed.connect(_move.bind(1))
	remove_button.pressed.connect(_remove)
	_populate_presets()
	_marker = ColorRect.new()
	_marker.color = MARKER_COLOR
	_marker.top_level = true
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.visible = false
	view.add_child(_marker)


func _on_open() -> void:
	_refresh()


func _on_area_changed() -> void:
	_selection = PackedInt32Array()
	_refresh()


func _populate_presets() -> void:
	preset_option.clear()
	preset_option.add_item("Apply Preset...")
	for id: StringName in LevelBackground.get_preset_ids():
		preset_option.add_item(LevelBackground.get_preset_name(id))
		preset_option.set_item_metadata(preset_option.item_count - 1, id)


func _refresh() -> void:
	if not is_open() or editor.level_handler.active_area == null:
		return
	
	_data = LevelBackground.resolve(editor.level_handler.active_area.background)
	_layers = LevelBackground.decode_layers(_data)
	if not _selection.is_empty() and _layer_at(_layers, _selection) == null:
		_selection = PackedInt32Array()
	
	_reveal()
	_rebuild_rows()
	_rebuild_fields()
	var siblings: Array[BackgroundLayer] = _siblings(_layers, _selection)
	var index: int = _selection.get(_selection.size() - 1) if not _selection.is_empty() else -1
	LD.set_disabled(move_up_button, index <= 0)
	LD.set_disabled(move_down_button, index < 0 or index >= siblings.size() - 1)
	LD.set_disabled(remove_button, index < 0)
	LD.set_disabled(duplicate_button, index < 0)
	var selected: BackgroundLayer = _layer_at(_layers, _selection) if index >= 0 else null
	Tooltip.set_text(add_group_button, "Ungroup" if selected is BackgroundLayerGroup else "Group Layer" if selected else "Add Group")


func _process(_delta: float) -> void:
	if _marker.visible and not view.get_viewport().gui_is_dragging():
		_marker.visible = false


func _rebuild_rows() -> void:
	for row: Button in _rows:
		row.button_group = null
	_rows.clear()
	for child: Node in row_container.get_children():
		child.queue_free()
	
	var backdrop: Button = _add_row("Backdrop", PackedInt32Array(), 0)
	backdrop.icon = ResourceCodec.decode(_data.get("texture")) as Texture2D
	_add_rows(_layers, PackedInt32Array(), 0)


func _add_rows(layers: Array[BackgroundLayer], prefix: PackedInt32Array, depth: int) -> void:
	for i: int in layers.size():
		var layer: BackgroundLayer = layers.get(i)
		var path: PackedInt32Array = prefix.duplicate()
		path.append(i)
		var row: Button = _add_row(_label_of(layer), path, depth)
		var expanded: bool = _open_groups.has(path)
		row.icon = (group_open_icon if expanded else group_icon) if layer is BackgroundLayerGroup else layer.get(&"texture") as Texture2D
		row.modulate.a = 1.0 if layer.enabled else DISABLED_ALPHA
		if layer is BackgroundLayerGroup and expanded:
			_add_rows((layer as BackgroundLayerGroup).layers, path, depth + 1)


func _add_row(text: String, path: PackedInt32Array, depth: int) -> Button:
	var row: Button = Button.new()
	row.text = text
	row.expand_icon = true
	row.add_theme_constant_override(&"icon_max_width", 22)
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.set_pressed_no_signal(path == _selection)
	row.pressed.connect(_select.bind(path))
	row.set_drag_forwarding(_get_drag_data.bind(row, path), _can_drop_data.bind(row, path), _drop_data.bind(row, path))
	GDSS.add_class(row, ROW_CLASS)
	var indent: MarginContainer = MarginContainer.new()
	indent.add_theme_constant_override(&"margin_left", INDENT * depth)
	indent.add_child(row)
	row_container.add_child(indent)
	_rows.append(row)
	return row


func _select(path: PackedInt32Array) -> void:
	_selection = path
	if _layer_at(_layers, path) is BackgroundLayerGroup:
		if _open_groups.has(path):
			_open_groups.erase(path)
		else:
			_open_groups.append(path)
	_revealed = path
	_refresh()


func _reveal() -> void:
	if _selection == _revealed:
		return
	
	_revealed = _selection
	for depth: int in range(1, _selection.size()):
		var ancestor: PackedInt32Array = _selection.slice(0, depth)
		if not _open_groups.has(ancestor):
			_open_groups.append(ancestor)


func _rebuild_fields() -> void:
	var fields: Array[Dictionary] = _backdrop_fields() if _selection.is_empty() else _layer_fields(_layer_at(_layers, _selection))
	var signature: String = "%s|%s" % [_selection, ",".join(fields.map(func(field: Dictionary) -> String: return field.get("name")))]
	if signature == _signature:
		for binding: PropertyBinding in _bindings:
			binding.refresh()
		return
	
	_signature = signature
	_bindings.clear()
	for child: Node in detail_container.get_children():
		child.queue_free()
	
	var sections: Dictionary[String, LDFoldSection] = {}
	for section_title: String in SECTION_ORDER:
		for field: Dictionary in fields:
			if field.get("section") != section_title:
				continue
			
			var binding: PropertyBinding = PropertyBinding.new(field.get("getter"), field.get("setter"), field.get("label"), field.get("info"))
			var widget: PropertyWidget = PropertyWidget.create(binding)
			if widget == null:
				continue
			
			if not sections.has(section_title):
				sections.set(section_title, _add_section(section_title))
			_compact(widget)
			sections.get(section_title).content.add_child(widget)
			_bindings.append(binding)


func _add_section(section_title: String) -> LDFoldSection:
	var section: LDFoldSection = section_scene.instantiate() as LDFoldSection
	detail_container.add_child(section)
	section.setup(section_title, _expanded.get(section_title, not COLLAPSED.has(section_title)))
	section.toggled.connect(func(expanded: bool) -> void: _expanded.set(section_title, expanded))
	return section


func _compact(widget: PropertyWidget) -> void:
	for option: Node in widget.find_children("*", "OptionButton", true, false):
		(option as OptionButton).fit_to_longest_item = false
		(option as OptionButton).clip_text = true
		(option as OptionButton).custom_minimum_size.x = OPTION_WIDTH


func _backdrop_fields() -> Array[Dictionary]:
	var fields: Array[Dictionary] = []
	var texture: Texture2D = ResourceCodec.decode(_data.get("texture")) as Texture2D
	if texture == null or texture is GradientTexture2D:
		fields.append(_backdrop_color_field("top_color", "Top Color", 1))
		fields.append(_backdrop_color_field("bottom_color", "Bottom Color", 0))
	else:
		fields.append(_backdrop_field("texture", "Texture", {"type": TYPE_OBJECT, "widget": &"Texture2D", "root": TEXTURE_ROOT}, "Sky"))
	
	fields.append(_backdrop_field("autoscroll", "Autoscroll", _ranged({"type": TYPE_VECTOR2}, &"autoscroll"), "Motion"))
	fields.append(_backdrop_field("follow_camera", "Follow Camera", {"type": TYPE_BOOL}, "Motion"))
	return fields


func _backdrop_field(key: String, label: String, info: Dictionary, section: String) -> Dictionary:
	return {
		"name": key,
		"section": section,
		"label": label,
		"info": info,
		"getter": func() -> Variant: return ResourceCodec.decode(_data.get(key)),
		"setter": func(value: Variant) -> void:
			_edit("Edit %s" % label, func(data: Dictionary, _layers_copy: Array[BackgroundLayer]) -> void: data.set(key, ResourceCodec.encode(value))),
	}


func _backdrop_color_field(key: String, label: String, stop: int) -> Dictionary:
	return {
		"name": key,
		"section": "Sky",
		"label": label,
		"info": {"type": TYPE_COLOR},
		"getter": func() -> Variant: return _gradient_colors(_data).get(stop),
		"setter": func(value: Variant) -> void:
			_edit("Edit %s" % label, func(data: Dictionary, _layers_copy: Array[BackgroundLayer]) -> void:
				var colors: PackedColorArray = _gradient_colors(data)
				colors.set(stop, value)
				data.set("texture", ResourceCodec.encode(_gradient_texture(colors)))),
	}


func _layer_fields(layer: BackgroundLayer) -> Array[Dictionary]:
	var fields: Array[Dictionary] = []
	if layer == null:
		return fields
	
	var path: PackedInt32Array = _selection
	for property: Dictionary in layer.get_property_list():
		var key: StringName = property.get("name")
		var usage: int = property.get("usage")
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE and usage & PROPERTY_USAGE_EDITOR) or HIDDEN.has(key):
			continue
		
		var info: Dictionary = property.duplicate()
		if info.get("type") == TYPE_OBJECT:
			if info.get("hint_string") != "Texture2D":
				continue
			info.set("widget", &"Texture2D")
			info.set("root", TEXTURE_ROOT)
		
		info = _ranged(info, key)
		if not PropertyWidget.supports(PropertyBinding.kind_of(info)):
			continue
		
		var label: String = LABELS.get(key, String(key).capitalize())
		fields.append({
			"name": key,
			"section": SECTIONS.get(key, "Advanced"),
			"rank": SECTIONS.keys().find(key) if SECTIONS.has(key) else SECTIONS.size() + fields.size(),
			"label": label,
			"info": info,
			"getter": func() -> Variant:
				var target: BackgroundLayer = _layer_at(_layers, path)
				return target.get(key) if target else null,
			"setter": _set_layer_value.bind(path, key, label),
		})
	
	fields.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("rank")) < int(b.get("rank")))
	return fields


static func _ranged(info: Dictionary, key: StringName) -> Dictionary:
	if not RANGES.has(key) or not info.get("type") in [TYPE_VECTOR2, TYPE_VECTOR2I]:
		return info
	
	var range_info: Array = RANGES.get(key)
	return info.merged({"widget": &"vector2_range", "hint_string": range_info.front(), "format": range_info.back()}, true)


func _set_layer_value(value: Variant, path: PackedInt32Array, key: StringName, label: String) -> void:
	_edit("Edit %s" % label, func(_data_copy: Dictionary, layers: Array[BackgroundLayer]) -> void:
		var target: BackgroundLayer = _layer_at(layers, path)
		var current: Variant = target.get(key)
		target.set(key, value if typeof(current) in [TYPE_NIL, TYPE_OBJECT] else type_convert(value, typeof(current))), UndoRedo.MERGE_ENDS)


func _get_drag_data(_at: Vector2, row: Button, path: PackedInt32Array) -> Variant:
	if path.is_empty():
		return null
	
	var preview: Label = Label.new()
	preview.text = row.text
	row.set_drag_preview(preview)
	return {"background_path": path}


func _can_drop_data(at: Vector2, data: Variant, row: Button, path: PackedInt32Array) -> bool:
	var source: PackedInt32Array = _drag_source(data)
	if source.is_empty() or _contains(source, path):
		_marker.visible = false
		return false
	
	var placement: int = _placement(at, row, path)
	var rect: Rect2 = row.get_global_rect()
	_marker.visible = true
	if placement == 0:
		_marker.global_position = rect.position
		_marker.size = rect.size
		_marker.color = Color(MARKER_COLOR, 0.35)
	else:
		_marker.global_position = Vector2(rect.position.x, rect.end.y - 1.0 if placement > 0 else rect.position.y - 1.0)
		_marker.size = Vector2(rect.size.x, 2.0)
		_marker.color = MARKER_COLOR
	return true


func _drop_data(at: Vector2, data: Variant, row: Button, path: PackedInt32Array) -> void:
	_marker.visible = false
	var source: PackedInt32Array = _drag_source(data)
	var placement: int = _placement(at, row, path)
	if path.is_empty():
		_move_to(source, PackedInt32Array(), 0)
	elif placement == 0:
		_move_to(source, path, -1)
	else:
		var index: int = path.get(path.size() - 1)
		_move_to(source, path.slice(0, path.size() - 1), index + 1 if placement > 0 else index)


func _placement(at: Vector2, row: Button, path: PackedInt32Array) -> int:
	var ratio: float = at.y / maxf(row.size.y, 1.0)
	if path.is_empty():
		return 1
	
	if _layer_at(_layers, path) is BackgroundLayerGroup and ratio > DROP_EDGE and ratio < 1.0 - DROP_EDGE:
		return 0
	
	return -1 if ratio < 0.5 else 1


func _move_to(source: PackedInt32Array, parent_path: PackedInt32Array, index: int) -> void:
	_edit("Move Background Layer", func(_data_copy: Dictionary, layers: Array[BackgroundLayer]) -> void:
		var parent: BackgroundLayerGroup = _layer_at(layers, parent_path) as BackgroundLayerGroup if not parent_path.is_empty() else null
		var target: Array[BackgroundLayer] = parent.layers if parent else layers
		var siblings: Array[BackgroundLayer] = _siblings(layers, source)
		var source_index: int = source.get(source.size() - 1)
		var layer: BackgroundLayer = siblings.get(source_index)
		siblings.remove_at(source_index)
		var at: int = target.size() if index < 0 else index
		if is_same(siblings, target) and source_index < at:
			at -= 1
		target.insert(clampi(at, 0, target.size()), layer)
		_selection = _path_of(layers, layer))


func _on_group_pressed() -> void:
	var selected: BackgroundLayer = _layer_at(_layers, _selection) if not _selection.is_empty() else null
	if selected == null:
		_insert(BackgroundLayerGroup)
		return
	
	var source: PackedInt32Array = _selection
	var index: int = source.get(source.size() - 1)
	if selected is BackgroundLayerGroup:
		_edit("Ungroup Background Layers", func(_data_copy: Dictionary, layers: Array[BackgroundLayer]) -> void:
			var siblings: Array[BackgroundLayer] = _siblings(layers, source)
			var group: BackgroundLayerGroup = siblings.get(index)
			siblings.remove_at(index)
			for i: int in group.layers.size():
				siblings.insert(index + i, group.layers.get(i))
			_selection = source)
		return
	
	_edit("Group Background Layer", func(_data_copy: Dictionary, layers: Array[BackgroundLayer]) -> void:
		var siblings: Array[BackgroundLayer] = _siblings(layers, source)
		var group: BackgroundLayerGroup = BackgroundLayerGroup.new()
		group.layer_name = "Group"
		group.layers.append(siblings.get(index))
		siblings.set(index, group)
		_selection = source)


static func _drag_source(data: Variant) -> PackedInt32Array:
	if data is Dictionary and (data as Dictionary).has("background_path"):
		return (data as Dictionary).get("background_path")
	
	return PackedInt32Array()


static func _contains(ancestor: PackedInt32Array, path: PackedInt32Array) -> bool:
	return path.size() >= ancestor.size() and path.slice(0, ancestor.size()) == ancestor


static func _path_of(layers: Array[BackgroundLayer], target: BackgroundLayer) -> PackedInt32Array:
	for i: int in layers.size():
		var layer: BackgroundLayer = layers.get(i)
		if layer == target:
			return PackedInt32Array([i])
		
		if layer is BackgroundLayerGroup:
			var inner: PackedInt32Array = _path_of((layer as BackgroundLayerGroup).layers, target)
			if not inner.is_empty():
				var path: PackedInt32Array = PackedInt32Array([i])
				path.append_array(inner)
				return path
	
	return PackedInt32Array()


func _insert(type: Script) -> void:
	var parent_path: PackedInt32Array = _selection
	var target: BackgroundLayer = _layer_at(_layers, _selection) if not _selection.is_empty() else null
	var path: PackedInt32Array = _selection.duplicate()
	if target is BackgroundLayerGroup:
		path.append((target as BackgroundLayerGroup).layers.size())
	elif _selection.is_empty():
		path = PackedInt32Array([_layers.size()])
	else:
		parent_path = _selection.slice(0, _selection.size() - 1)
		path.set(path.size() - 1, path.get(path.size() - 1) + 1)
	
	var layer: BackgroundLayer = type.new() as BackgroundLayer
	layer.layer_name = "Group" if layer is BackgroundLayerGroup else "Layer"
	_selection = path
	_edit("Add Background Layer", func(_data_copy: Dictionary, layers: Array[BackgroundLayer]) -> void:
		var siblings: Array[BackgroundLayer] = layers
		var parent: BackgroundLayer = _layer_at(layers, parent_path) if not parent_path.is_empty() else null
		if parent is BackgroundLayerGroup:
			siblings = (parent as BackgroundLayerGroup).layers
		siblings.insert(path.get(path.size() - 1), layer))


func _duplicate() -> void:
	if _selection.is_empty():
		return
	
	var source: PackedInt32Array = _selection
	var index: int = source.get(source.size() - 1)
	_selection = source.duplicate()
	_selection.set(source.size() - 1, index + 1)
	_edit("Duplicate Background Layer", func(_data_copy: Dictionary, layers: Array[BackgroundLayer]) -> void:
		var siblings: Array[BackgroundLayer] = _siblings(layers, source)
		siblings.insert(index + 1, ResourceCodec.decode(ResourceCodec.encode(siblings.get(index))) as BackgroundLayer))


func _move(direction: int) -> void:
	if _selection.is_empty():
		return
	
	var source: PackedInt32Array = _selection
	var index: int = source.get(source.size() - 1)
	_selection = source.duplicate()
	_selection.set(source.size() - 1, index + direction)
	_edit("Move Background Layer", func(_data_copy: Dictionary, layers: Array[BackgroundLayer]) -> void:
		var siblings: Array[BackgroundLayer] = _siblings(layers, source)
		var layer: BackgroundLayer = siblings.get(index)
		siblings.remove_at(index)
		siblings.insert(index + direction, layer))


func _remove() -> void:
	if _selection.is_empty():
		return
	
	var source: PackedInt32Array = _selection
	var index: int = source.get(source.size() - 1)
	_selection = source.slice(0, source.size() - 1)
	if index > 0:
		_selection.append(index - 1)
	
	_edit("Remove Background Layer", func(_data_copy: Dictionary, layers: Array[BackgroundLayer]) -> void:
		_siblings(layers, source).remove_at(index))


func _on_preset_selected(index: int) -> void:
	preset_option.select(0)
	if index <= 0:
		return
	
	var level: LDLevelHandler = editor.level_handler
	_selection = PackedInt32Array()
	level.set_background(level.active_area, LevelBackground.load_preset(preset_option.get_item_metadata(index)), "Apply Background Preset")


func _edit(action_name: String, mutate: Callable, merge: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE) -> void:
	var level: LDLevelHandler = editor.level_handler
	var data: Dictionary = LevelBackground.resolve(level.active_area.background).duplicate(true)
	var layers: Array[BackgroundLayer] = LevelBackground.decode_layers(data)
	mutate.call(data, layers)
	data.set("layers", ResourceCodec.encode(layers))
	level.set_background(level.active_area, data, action_name, merge)


static func _layer_at(layers: Array[BackgroundLayer], path: PackedInt32Array) -> BackgroundLayer:
	var current: Array[BackgroundLayer] = layers
	var layer: BackgroundLayer = null
	for index: int in path:
		if layer != null:
			if layer is not BackgroundLayerGroup:
				return null
			current = (layer as BackgroundLayerGroup).layers
		if index < 0 or index >= current.size():
			return null
		layer = current.get(index)
	
	return layer


static func _siblings(layers: Array[BackgroundLayer], path: PackedInt32Array) -> Array[BackgroundLayer]:
	if path.size() <= 1:
		return layers
	
	var parent: BackgroundLayerGroup = _layer_at(layers, path.slice(0, path.size() - 1)) as BackgroundLayerGroup
	return parent.layers if parent else layers


static func _label_of(layer: BackgroundLayer) -> String:
	if not layer.layer_name.is_empty():
		return layer.layer_name
	
	return "Group" if layer is BackgroundLayerGroup else "Layer"


static func _gradient_colors(data: Dictionary) -> PackedColorArray:
	var texture: GradientTexture2D = ResourceCodec.decode(data.get("texture")) as GradientTexture2D
	if texture and texture.gradient and texture.gradient.colors.size() >= 2:
		return texture.gradient.colors
	
	return PackedColorArray([Color(0.3, 0.46, 0.78), Color(0.57, 0.74, 1.0)])


static func _gradient_texture(colors: PackedColorArray) -> GradientTexture2D:
	var gradient: Gradient = Gradient.new()
	gradient.colors = colors
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0.0, 1.0)
	texture.fill_to = Vector2.ZERO
	return texture
