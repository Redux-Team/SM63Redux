class_name LDAreaPanel
extends LDPanel

const ROW_CLASS: String = "ListRow"
const WAVE_MASK: Texture2D = preload("uid://c0rwnbt8w3qel")

@export var row_container: VBoxContainer
@export var count_label: Label
@export var add_button: BaseButton
@export var move_up_button: BaseButton
@export var move_down_button: BaseButton
@export var remove_button: BaseButton
@export var detail_container: VBoxContainer
@export var switch_button: BaseButton

var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _selected: LevelArea
var _name_binding: PropertyBinding


func _setup() -> void:
	super()
	var level: LDLevelHandler = editor.level_handler
	level.structure_changed.connect(_refresh)
	level.area_changed.connect(_on_area_changed)
	add_button.pressed.connect(level.add_area)
	move_up_button.pressed.connect(func() -> void: level.move_area(_selected, -1))
	move_down_button.pressed.connect(func() -> void: level.move_area(_selected, 1))
	remove_button.pressed.connect(_on_remove)
	switch_button.pressed.connect(_switch)
	_name_binding = PropertyBinding.new(
			func() -> Variant: return _selected.area_name if _selected else "",
			func(value: Variant) -> void: level.rename_area(_selected, value),
			"Name",
			{ "type": TYPE_STRING },
	)
	var widget: PropertyWidget = PropertyWidget.create(_name_binding)
	detail_container.add_child(widget)
	detail_container.move_child(widget, 0)


func _on_open() -> void:
	_selected = editor.level_handler.active_area
	_refresh()


func _on_area_changed(area: LevelArea) -> void:
	_selected = area
	_refresh()


func _refresh() -> void:
	var level: LDLevelHandler = editor.level_handler
	if not is_open():
		return
	
	if not level.areas.has(_selected):
		_selected = level.active_area
	
	for row: Button in _rows:
		row.button_group = null
		row.queue_free()
	_rows.clear()
	
	for i: int in level.areas.size():
		var area: LevelArea = level.areas[i]
		var row: Button = Button.new()
		row.text = area.area_name if not area.area_name.is_empty() else "Area %d" % (i + 1)
		row.toggle_mode = true
		row.button_group = _row_group
		row.focus_mode = Control.FOCUS_NONE
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		row.set_pressed_no_signal(area == _selected)
		row.pressed.connect(_select.bind(area))
		GDSS.add_class(row, ROW_CLASS)
		row_container.add_child(row)
		_rows.append(row)
	
	var at: int = level.areas.find(_selected)
	var count: int = _selected.get_all_objects().size()
	count_label.text = "%d %s" % [count, "object" if count == 1 else "objects"]
	LD.set_disabled(move_up_button, at <= 0)
	LD.set_disabled(move_down_button, at >= level.areas.size() - 1)
	LD.set_disabled(remove_button, level.areas.size() <= 1)
	LD.set_disabled(switch_button, _selected == level.active_area)
	_name_binding.refresh()


func _select(area: LevelArea) -> void:
	_selected = area
	_refresh()


func _switch() -> void:
	var area: LevelArea = _selected
	if area == editor.level_handler.active_area or Singleton.is_transitioning():
		return
	
	(
			Singleton.build_screen_transition()
			.set_wave()
			.set_texture(WAVE_MASK)
			.set_wave_scale(4.0)
			.set_hold_duration(0.0)
			.set_swap(editor.level_handler.set_active_area.bind(area))
			.done()
	)


func _on_remove() -> void:
	var level: LDLevelHandler = editor.level_handler
	var area: LevelArea = _selected
	var count: int = area.get_all_objects().size()
	if count == 0:
		level.remove_area(area)
		return
	
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Remove Area"
	dialog.dialog_text = "Remove \"%s\" and its %d object(s)?" % [
		area.area_name,
		count,
	]
	dialog.confirmed.connect(level.remove_area.bind(area))
	dialog.visibility_changed.connect(func() -> void:
			if not dialog.visible:
				dialog.queue_free())
	view.add_child(dialog)
	dialog.popup_centered()
