class_name LDLayerPanel
extends LDPanel

const ROW_CLASS: String = "ListRow"

@export var row_container: VBoxContainer
@export var count_label: Label
@export var add_button: BaseButton
@export var move_up_button: BaseButton
@export var move_down_button: BaseButton
@export var remove_button: BaseButton
@export var detail_container: VBoxContainer
@export var lock_icon: Texture2D

var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _bindings: Array[PropertyBinding] = []
var _widgets: Dictionary[StringName, PropertyWidget] = {}


func _setup() -> void:
	super()
	var level: LDLevelHandler = editor.level_handler
	level.layer_changed.connect(_refresh.unbind(1))
	level.structure_changed.connect(_refresh)
	add_button.pressed.connect(func() -> void: level.add_layer(level.active_layer))
	move_up_button.pressed.connect(func() -> void: level.move_layer(level.active_layer, 1))
	move_down_button.pressed.connect(func() -> void: level.move_layer(level.active_layer, -1))
	remove_button.pressed.connect(_on_remove)


func _on_open() -> void:
	_refresh()


func _refresh() -> void:
	var level: LDLevelHandler = editor.level_handler
	if not is_open() or level.active_layer == null:
		return
	
	var layers: Array[LevelLayer] = level.active_area.get_layers()
	layers.reverse()
	var anchor: LevelLayer = level.get_anchor_layer()
	for row: Button in _rows:
		row.button_group = null
		row.queue_free()
	_rows.clear()
	
	for layer: LevelLayer in layers:
		var row: Button = _make_row(level.get_layer_label(layer), layer == anchor)
		row.set_pressed_no_signal(layer == level.active_layer)
		row.pressed.connect(level.set_active_layer.bind(layer))
		row_container.add_child(row)
		_rows.append(row)
	
	if _widgets.is_empty():
		_build_fields()
	
	var layer: LevelLayer = level.active_layer
	var locked: bool = layer == anchor
	var count: int = layer.get_objects().size()
	count_label.text = "%d %s" % [count, "object" if count == 1 else "objects"]
	LD.set_disabled(move_up_button, layer == layers.front())
	LD.set_disabled(move_down_button, layer == layers.back())
	LD.set_disabled(remove_button, locked or layers.size() <= 1)
	_widgets.get(&"layer_name").set_editable(not locked)
	_widgets.get(&"is_decoration").set_editable(not locked)
	_widgets.get(&"distance").set_editable(not locked and layer.is_decoration)
	for binding: PropertyBinding in _bindings:
		binding.refresh()


func _build_fields() -> void:
	_add_field(&"layer_name", "Name", {"type": TYPE_STRING})
	_add_field(&"modulation", "Modulate", {"type": TYPE_COLOR})
	_add_field(&"is_decoration", "Decoration", {"type": TYPE_BOOL})
	_add_field(&"distance", "Distance", {
		"type": TYPE_FLOAT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "%s,%s,0.1" % [LevelLayer.DISTANCE_MIN, LevelLayer.DISTANCE_MAX],
		"format": "%.1fx",
	})


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


func _make_row(text: String, locked: bool) -> Button:
	var row: Button = Button.new()
	row.text = text
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	GDSS.add_class(row, ROW_CLASS)
	if locked:
		row.icon = lock_icon
		row.icon_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.expand_icon = true
	return row


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
