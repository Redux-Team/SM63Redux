class_name LDLayerPanel
extends LDPanel

const ROW_CLASS: String = "ListRow"
const INDENT: int = 14
const DROP_EDGE: float = 0.3
const MARKER_COLOR: Color = Color("#6496ed")
const DISABLED_ROW_ALPHA: float = 0.45
const ICON_SIZE: float = 12.0
const ICON_SLOT: float = 16.0

@export var row_container: VBoxContainer
@export var count_label: Label
@export var add_button: BaseButton
@export var group_button: BaseButton
@export var move_up_button: BaseButton
@export var move_down_button: BaseButton
@export var remove_button: BaseButton
@export var detail_container: VBoxContainer
@export var lock_icon: Texture2D
@export var folder_icon: Texture2D
@export var folder_open_icon: Texture2D
@export var visible_icon: Texture2D
@export var hidden_icon: Texture2D

var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _bindings: Array[PropertyBinding] = []
var _widgets: Dictionary[StringName, PropertyWidget] = {}
var _group_bindings: Array[PropertyBinding] = []
var _group_widgets: Dictionary[StringName, PropertyWidget] = {}
var _selected_group: StringName = &""
var _marker: ColorRect
var _open_groups: Array[StringName] = []
var _revealed: Array = []


func _setup() -> void:
	super()
	var level: LDLevelHandler = editor.level_handler
	level.layer_changed.connect(_on_layer_changed.unbind(1))
	level.structure_changed.connect(_refresh)
	add_button.pressed.connect(func() -> void: level.add_layer(level.active_layer))
	group_button.pressed.connect(_on_group_pressed)
	move_up_button.pressed.connect(func() -> void: level.move_layer(level.active_layer, -1))
	move_down_button.pressed.connect(func() -> void: level.move_layer(level.active_layer, 1))
	remove_button.pressed.connect(_on_remove)
	_marker = ColorRect.new()
	_marker.top_level = true
	_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_marker.visible = false
	view.add_child(_marker)


func _process(_delta: float) -> void:
	if _marker.visible and not view.get_viewport().gui_is_dragging():
		_marker.visible = false


func _on_open() -> void:
	_refresh()


func _on_layer_changed() -> void:
	_selected_group = &""
	_refresh()


func _reveal(layer: LevelLayer) -> void:
	var revealed: Array = [layer, layer.group]
	if revealed == _revealed:
		return
	
	_revealed = revealed
	if not layer.group.is_empty() and not _open_groups.has(layer.group):
		_open_groups.append(layer.group)


func _refresh() -> void:
	var level: LDLevelHandler = editor.level_handler
	if not is_open() or level.active_layer == null:
		return
	
	if not _selected_group.is_empty() and level.get_layer_group(_selected_group).is_empty():
		_selected_group = &""
	
	_reveal(level.active_layer)
	
	_rebuild_rows()
	if _widgets.is_empty():
		_build_fields()
	
	var layers: Array[LevelLayer] = level.active_area.get_layers()
	var layer: LevelLayer = level.active_layer
	var locked: bool = layer == level.get_anchor_layer()
	var grouped: bool = not _selected_group.is_empty()
	var count: int = level.get_group_members(_selected_group).size() if grouped else layer.get_objects().size()
	count_label.text = "%d %s" % [count, ("layer" if count == 1 else "layers") if grouped else ("object" if count == 1 else "objects")]
	LD.set_disabled(move_up_button, grouped or layer == layers.front())
	LD.set_disabled(move_down_button, grouped or layer == layers.back())
	LD.set_disabled(remove_button, grouped or locked or layers.size() <= 1)
	Tooltip.set_text(group_button, "Ungroup" if grouped else "Remove from Group" if not layer.group.is_empty() else "Group Layer")
	for widget: PropertyWidget in _widgets.values():
		widget.visible = not grouped
	for widget: PropertyWidget in _group_widgets.values():
		widget.visible = grouped
	_group_widgets.get(&"is_decoration").set_editable(not level.group_contains_anchor(_selected_group))
	_group_widgets.get(&"enabled").set_editable(not level.group_contains_anchor(_selected_group))
	_widgets.get(&"layer_name").set_editable(not locked)
	_widgets.get(&"enabled").set_editable(not locked)
	_widgets.get(&"is_decoration").set_editable(not locked)
	_widgets.get(&"distance").set_editable(not locked and layer.is_decoration)
	_widgets.get(&"silhouette").visible = not grouped and layer.is_effective_decoration()
	for binding: PropertyBinding in _bindings + _group_bindings:
		binding.refresh()


func _rebuild_rows() -> void:
	var level: LDLevelHandler = editor.level_handler
	for row: Button in _rows:
		row.button_group = null
	_rows.clear()
	for child: Node in row_container.get_children():
		child.queue_free()
	
	var layers: Array[LevelLayer] = level.active_area.get_layers()
	var anchor: LevelLayer = level.get_anchor_layer()
	var listed: Array[StringName] = []
	for layer: LevelLayer in layers:
		var group: Dictionary = level.get_layer_group(layer.group)
		if group.is_empty():
			_add_layer_row(layer, anchor, 0)
			continue
		
		if listed.has(layer.group):
			continue
		
		listed.append(layer.group)
		var expanded: bool = _open_groups.has(layer.group)
		var row: Button = _add_row(group.get("name"), 0, _selected_group == layer.group)
		row.icon = folder_open_icon if expanded else folder_icon
		row.pressed.connect(_select_group.bind(layer.group))
		_forward_drag(row, null, layer.group)
		var group_enabled: bool = group.get("enabled", true)
		var group_visible: bool = group.get("visible", true)
		_add_row_icons(row, group_visible, func() -> void: level.set_layer_group_property(layer.group, &"visible", not group_visible), false)
		if not group_enabled:
			row.modulate.a = DISABLED_ROW_ALPHA
		if not expanded:
			continue
		
		for member: LevelLayer in layers:
			if member.group == layer.group:
				_add_layer_row(member, anchor, 1)


func _add_layer_row(layer: LevelLayer, anchor: LevelLayer, depth: int) -> void:
	var level: LDLevelHandler = editor.level_handler
	var row: Button = _add_row(level.get_layer_label(layer), depth, _selected_group.is_empty() and layer == level.active_layer)
	row.pressed.connect(_select_layer.bind(layer))
	_forward_drag(row, layer, &"")
	_add_row_icons(row, layer.editor_visible, func() -> void: level.set_layer_property(layer, &"editor_visible", not layer.editor_visible), layer == anchor)
	if not layer.is_effective_enabled():
		row.modulate.a = DISABLED_ROW_ALPHA


func _add_row(text: String, depth: int, pressed: bool) -> Button:
	var row: Button = Button.new()
	row.text = text
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = true
	row.expand_icon = true
	row.add_theme_constant_override(&"icon_max_width", 16)
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.set_pressed_no_signal(pressed)
	GDSS.add_class(row, ROW_CLASS)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var line: HBoxContainer = HBoxContainer.new()
	line.add_child(row)
	var indent: MarginContainer = MarginContainer.new()
	indent.add_theme_constant_override(&"margin_left", INDENT * depth)
	indent.add_child(line)
	row_container.add_child(indent)
	_rows.append(row)
	return row


func _add_row_icons(row: Button, is_visible: bool, on_toggle: Callable, locked: bool) -> void:
	var eye: TextureButton = TextureButton.new()
	eye.focus_mode = Control.FOCUS_NONE
	eye.texture_normal = visible_icon if is_visible else hidden_icon
	eye.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	eye.pressed.connect(on_toggle)
	Tooltip.set_text(eye, "Hide in Editor" if is_visible else "Show in Editor", Tooltip.Placement.RIGHT)
	row.get_parent().add_child(_icon_slot(eye))
	var lock: TextureRect = TextureRect.new()
	lock.texture = lock_icon if locked else null
	if locked:
		Tooltip.set_text(lock, "Player layer (always enabled)", Tooltip.Placement.RIGHT)
	row.get_parent().add_child(_icon_slot(lock))


func _icon_slot(icon: Control) -> Control:
	var slot: CenterContainer = CenterContainer.new()
	slot.custom_minimum_size = Vector2(ICON_SLOT, ICON_SLOT)
	slot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
	if icon is TextureButton:
		(icon as TextureButton).ignore_texture_size = true
		(icon as TextureButton).stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	elif icon is TextureRect:
		(icon as TextureRect).expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		(icon as TextureRect).stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slot.add_child(icon)
	return slot


func _select_layer(layer: LevelLayer) -> void:
	_selected_group = &""
	if layer == editor.level_handler.active_layer:
		_refresh()
	else:
		editor.level_handler.set_active_layer(layer)


func _select_group(group: StringName) -> void:
	_selected_group = group
	if _open_groups.has(group):
		_open_groups.erase(group)
	else:
		_open_groups.append(group)
	_refresh()


func _build_fields() -> void:
	_add_field(&"layer_name", "Name", {"type": TYPE_STRING})
	_add_field(&"modulation", "Modulate", {"type": TYPE_COLOR})
	_add_field(&"editor_visible", "Visible", {"type": TYPE_BOOL})
	_add_field(&"enabled", "Enabled", {"type": TYPE_BOOL})
	_add_field(&"is_decoration", "Decoration", {"type": TYPE_BOOL})
	_add_field(&"silhouette", "Render Silhouette", {"type": TYPE_BOOL})
	_add_field(&"distance", "Distance", {
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%s,%s,0.1" % [LevelLayer.DISTANCE_MIN, LevelLayer.DISTANCE_MAX],
		"format": "%.1fx",
	})
	_add_group_field(&"name", "Group Name", "", {"type": TYPE_STRING})
	_add_group_field(&"modulation", "Modulate", Color.WHITE, {"type": TYPE_COLOR})
	_add_group_field(&"visible", "Visible", true, {"type": TYPE_BOOL})
	_add_group_field(&"enabled", "Enabled", true, {"type": TYPE_BOOL})
	_add_group_field(&"is_decoration", "Decoration", false, {"type": TYPE_BOOL})
	_add_group_field(&"distance", "Distance", 0.0, {
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%s,%s,0.1" % [LevelLayer.DISTANCE_MIN, LevelLayer.DISTANCE_MAX],
		"format": "%+.1fx",
	})


func _add_group_field(property: StringName, label: String, default: Variant, info: Dictionary) -> void:
	var level: LDLevelHandler = editor.level_handler
	var binding: PropertyBinding = PropertyBinding.new(
		func() -> Variant: return level.get_layer_group(_selected_group).get(property, default),
		func(value: Variant) -> void:
			if property != &"name" or not String(value).is_empty():
				level.set_layer_group_property(_selected_group, property, value),
		label, info)
	var widget: PropertyWidget = PropertyWidget.create(binding)
	detail_container.add_child(widget)
	_group_bindings.append(binding)
	_group_widgets.set(property, widget)


func _add_field(property: StringName, label: String, info: Dictionary) -> void:
	var level: LDLevelHandler = editor.level_handler
	var binding: PropertyBinding = PropertyBinding.new(
		func() -> Variant: return level.active_layer.get(property),
		func(value: Variant) -> void: level.set_layer_property(level.active_layer, property, value),
		label, info)
	var widget: PropertyWidget = PropertyWidget.create(binding)
	detail_container.add_child(widget)
	_bindings.append(binding)
	_widgets.set(property, widget)


func _on_group_pressed() -> void:
	var level: LDLevelHandler = editor.level_handler
	if not _selected_group.is_empty():
		level.ungroup_layers(_selected_group)
	elif level.active_layer.group.is_empty():
		_selected_group = level.group_layer(level.active_layer)
		_refresh()
	else:
		var others: Array[LevelLayer] = level.get_group_members(level.active_layer.group)
		others.erase(level.active_layer)
		if others.is_empty():
			level.ungroup_layers(level.active_layer.group)
		else:
			level.move_layers([level.active_layer], others.back(), true, &"")


func _forward_drag(row: Button, layer: LevelLayer, group: StringName) -> void:
	row.set_drag_forwarding(_get_drag_data.bind(row, layer, group), _can_drop_data.bind(row, layer, group), _drop_data.bind(row, layer, group))


func _get_drag_data(_at: Vector2, row: Button, layer: LevelLayer, group: StringName) -> Variant:
	var preview: Label = Label.new()
	preview.text = row.text
	row.set_drag_preview(preview)
	return {"layer": layer, "group": group}


func _can_drop_data(at: Vector2, data: Variant, row: Button, layer: LevelLayer, group: StringName) -> bool:
	var drop: Dictionary = _resolve_drop(at, data, row, layer, group)
	if drop.is_empty():
		_marker.visible = false
		return false
	
	var rect: Rect2 = row.get_global_rect()
	_marker.visible = true
	if drop.get("into"):
		_marker.global_position = rect.position
		_marker.size = rect.size
		_marker.color = Color(MARKER_COLOR, 0.35)
	else:
		_marker.global_position = Vector2(rect.position.x, rect.position.y - 1.0 if drop.get("above") else rect.end.y - 1.0)
		_marker.size = Vector2(rect.size.x, 2.0)
		_marker.color = MARKER_COLOR
	return true


func _drop_data(at: Vector2, data: Variant, row: Button, layer: LevelLayer, group: StringName) -> void:
	_marker.visible = false
	var drop: Dictionary = _resolve_drop(at, data, row, layer, group)
	if not drop.is_empty():
		editor.level_handler.move_layers(drop.get("moved"), drop.get("target"), drop.get("in_front"), drop.get("group"))


func _resolve_drop(at: Vector2, data: Variant, row: Button, layer: LevelLayer, group: StringName) -> Dictionary:
	if not data is Dictionary or not (data as Dictionary).has("group"):
		return {}
	
	var level: LDLevelHandler = editor.level_handler
	var dragged_group: StringName = (data as Dictionary).get("group")
	var moved: Array[LevelLayer] = []
	if dragged_group.is_empty():
		moved.append((data as Dictionary).get("layer"))
	else:
		moved = level.get_group_members(dragged_group)
	var ratio: float = at.y / maxf(row.size.y, 1.0)
	var above: bool = ratio < 0.5
	var members: Array[LevelLayer] = []
	if not group.is_empty():
		members = level.get_group_members(group)
	var target_group: StringName = layer.group if layer else &""
	var into: bool = not group.is_empty() and dragged_group.is_empty() and ratio >= DROP_EDGE
	if not dragged_group.is_empty() and not target_group.is_empty():
		members = level.get_group_members(target_group)
		group = target_group
		layer = null
	
	var drop: Dictionary = {"moved": moved, "above": above, "into": into}
	if not group.is_empty():
		drop.set("target", members.front() if above and not into else members.back())
		drop.set("in_front", into or not above)
		drop.set("group", group if into else dragged_group)
	else:
		drop.set("target", layer)
		drop.set("in_front", not above)
		drop.set("group", dragged_group if not dragged_group.is_empty() else target_group)
	
	if moved.has(drop.get("target")) or drop.get("target") == null:
		return {}
	
	return drop


func _on_remove() -> void:
	var level: LDLevelHandler = editor.level_handler
	var layer: LevelLayer = level.active_layer
	var count: int = layer.get_objects().size()
	if count == 0:
		level.remove_layer(layer)
		return
	
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Remove Layer"
	dialog.dialog_text = "Remove \"%s\" and its %d object(s)?" % [level.get_layer_label(layer), count]
	dialog.confirmed.connect(level.remove_layer.bind(layer))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free())
	view.add_child(dialog)
	dialog.popup_centered()
