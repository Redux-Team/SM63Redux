class_name LDAreaEditor
extends MarginContainer

## Manages the level's areas: lists them, picks the active one (covering the swap with a wave
## transition), adds/removes/reorders them, and renames the selected area. Each area owns its own
## layers and background (edited in the Layers / Background windows). Mirrors the Layers panel.


const WAVE_MASK: Texture2D = preload("uid://c0rwnbt8w3qel")
const ROW_CLASS: StringName = &"ListRow"


@export var row_container: VBoxContainer
@export var add_button: Button
@export var move_up_button: Button
@export var move_down_button: Button
@export var remove_button: Button
@export var count_label: Label

@export var detail: VBoxContainer
@export var name_edit: LineEdit
@export var switch_button: Button


var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _setting_fields: bool = false


func _ready() -> void:
	add_button.pressed.connect(_on_add)
	move_up_button.pressed.connect(_on_move.bind(-1))
	move_down_button.pressed.connect(_on_move.bind(1))
	remove_button.pressed.connect(_on_remove)
	switch_button.pressed.connect(_on_switch_pressed)
	name_edit.text_changed.connect(_on_name_changed)
	# Snap the field back to the actual name on blur, in case a rejected (duplicate/empty) edit was
	# left in it.
	name_edit.focus_exited.connect(_resync_name)


func _on_show() -> void:
	_refresh()


func _level() -> LDLevel:
	return LD.get_level()


#region List

func _refresh() -> void:
	var level: LDLevel = _level()
	var areas: Array[LDArea] = level.get_areas()
	_setting_fields = true
	_clear_rows()
	for i: int in areas.size():
		var row: Button = _make_row(_label(areas[i], i))
		row_container.add_child(row)
		row.pressed.connect(_on_row_pressed.bind(i))
		_rows.append(row)
	var active: int = level.get_active_index()
	if active >= 0 and active < _rows.size():
		_rows[active].button_pressed = true
	_setting_fields = false
	_show_detail(active)


func _make_row(text: String) -> Button:
	var row: Button = Button.new()
	row.text = text
	row.toggle_mode = true
	row.button_group = _row_group
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.set_meta(&"gdss_classes", PackedStringArray([ROW_CLASS]))
	return row


func _clear_rows() -> void:
	for row: Button in _rows:
		row.button_group = null
		row.queue_free()
	_rows.clear()


func _label(area: LDArea, index: int) -> String:
	return area.area_name if not area.area_name.is_empty() else "Area %d" % (index + 1)


func _selected_index() -> int:
	for i: int in _rows.size():
		if _rows[i].button_pressed:
			return i
	return -1


func _selected_area() -> LDArea:
	var idx: int = _selected_index()
	if idx < 0:
		return null
	return _level().get_areas()[idx]


## Selecting an area only shows its detail. Switching to it is deliberate: press the Switch button.
func _on_row_pressed(pos: int) -> void:
	if _setting_fields:
		return
	_show_detail(pos)


func _on_switch_pressed() -> void:
	_switch_to(_selected_index())


## Switches the visible area, covering the swap with a wave transition.
func _switch_to(index: int) -> void:
	if index < 0 or index >= _level().get_areas().size() or index == _level().get_active_index():
		return
	Singleton.build_screen_transition().set_wave().set_texture(WAVE_MASK).set_wave_scale(4.0).load(func() -> void:
		_level().set_active_area_index(index)
		_refresh()
	).done()


func _on_add() -> void:
	var level: LDLevel = _level()
	var area: LDArea = level.add_area(level.suggest_area_name())
	# New areas are independently playable, so give them a player spawn like a fresh level.
	LD.get_save_load_handler()._ensure_player_spawn(area)
	LD.get_save_load_handler().save_session()
	_refresh()
	var last: int = level.get_areas().size() - 1
	if last >= 0 and last < _rows.size():
		_rows[last].button_pressed = true
		_show_detail(last)


func _on_move(delta: int) -> void:
	var area: LDArea = _selected_area()
	if not area:
		return
	_level().move_area(area, delta)
	LD.get_save_load_handler().save_session()
	_refresh()


func _on_remove() -> void:
	var area: LDArea = _selected_area()
	if not area or _level().get_areas().size() <= 1:
		return
	if area.get_all_objects().is_empty():
		_remove(area)
		return
	# Area has objects: confirm before discarding them.
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Remove Area"
	dialog.dialog_text = "Remove \"%s\" and its %d object(s)?" % [
		_label(area, _level().get_areas().find(area)), area.get_all_objects().size()]
	dialog.confirmed.connect(func() -> void: _remove(area))
	dialog.visibility_changed.connect(func() -> void:
		if not dialog.visible:
			dialog.queue_free()
	)
	add_child(dialog)
	dialog.popup_centered()


func _remove(area: LDArea) -> void:
	_level().remove_area(area)
	LD.get_save_load_handler().save_session()
	_refresh()

#endregion


#region Detail

func _show_detail(index: int) -> void:
	var areas: Array[LDArea] = _level().get_areas()
	var count: int = areas.size()
	var has_area: bool = index >= 0 and index < count
	detail.visible = has_area
	if has_area:
		var objects: int = areas[index].get_all_objects().size()
		var noun: String = "object" if objects == 1 else "objects"
		count_label.text = "%d %s" % [objects, noun]
	else:
		count_label.text = ""
	move_up_button.disabled = not has_area or index == 0
	GDSS.refresh(move_up_button)
	move_down_button.disabled = not has_area or index >= count - 1
	GDSS.refresh(move_down_button)
	remove_button.disabled = not has_area or count <= 1
	GDSS.refresh(remove_button)
	switch_button.disabled = not has_area or index == _level().get_active_index()
	GDSS.refresh(switch_button)
	if not has_area:
		return
	_setting_fields = true
	name_edit.text = areas[index].area_name
	_setting_fields = false


func _resync_name() -> void:
	var idx: int = _selected_index()
	if idx >= 0:
		name_edit.text = _level().get_areas()[idx].area_name


func _on_name_changed(_text: String) -> void:
	if _setting_fields:
		return
	var idx: int = _selected_index()
	if idx < 0:
		return
	var area: LDArea = _level().get_areas()[idx]
	_level().rename_area(area, LDText.sanitize_edit(name_edit))
	LD.get_save_load_handler().save_session()
	_rows[idx].text = _label(area, idx)

#endregion
