class_name LDAreaEditor
extends MarginContainer

## Manages the level's areas: lists them, picks the active one (covering the swap with a wave
## transition), adds/removes/reorders them, and renames the selected area. Each area owns its own
## layers and background (edited in the Layers / Background windows). Mirrors the Layers panel.


const WAVE_MASK: Texture2D = preload("uid://c0rwnbt8w3qel")


@export var area_list: ItemList
@export var add_button: Button
@export var move_up_button: Button
@export var move_down_button: Button
@export var remove_button: Button

@export var detail: VBoxContainer
@export var name_edit: LineEdit
@export var switch_button: Button


var _setting_fields: bool = false


func _ready() -> void:
	area_list.item_selected.connect(_on_area_selected)
	area_list.item_activated.connect(_switch_to)
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
	_setting_fields = true
	area_list.clear()
	for i: int in level.get_areas().size():
		area_list.add_item(_label(level.get_areas()[i], i))
	var active: int = level.get_active_index()
	if active >= 0 and active < area_list.item_count:
		area_list.select(active)
	_setting_fields = false
	_show_detail(active)


func _label(area: LDArea, index: int) -> String:
	return area.area_name if not area.area_name.is_empty() else "Area %d" % (index + 1)


func _selected_area() -> LDArea:
	var sel: PackedInt32Array = area_list.get_selected_items()
	if sel.is_empty():
		return null
	return _level().get_areas()[sel[0]]


## Selecting an area only shows its detail. Switching to it is deliberate: double-click the list
## (item_activated) or press the Switch button.
func _on_area_selected(index: int) -> void:
	if _setting_fields:
		return
	_show_detail(index)


func _on_switch_pressed() -> void:
	var sel: PackedInt32Array = area_list.get_selected_items()
	if sel.is_empty():
		return
	_switch_to(sel[0])


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
	area_list.select(level.get_areas().size() - 1)
	_show_detail(level.get_areas().size() - 1)


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
	var count: int = _level().get_areas().size()
	var has_area: bool = index >= 0 and index < count
	detail.visible = has_area
	move_up_button.disabled = not has_area or index == 0
	move_down_button.disabled = not has_area or index >= count - 1
	remove_button.disabled = not has_area or count <= 1
	switch_button.disabled = not has_area or index == _level().get_active_index()
	if not has_area:
		return
	_setting_fields = true
	name_edit.text = _level().get_areas()[index].area_name
	_setting_fields = false


func _resync_name() -> void:
	var sel: PackedInt32Array = area_list.get_selected_items()
	if not sel.is_empty():
		name_edit.text = _level().get_areas()[sel[0]].area_name


func _on_name_changed(_text: String) -> void:
	if _setting_fields:
		return
	var sel: PackedInt32Array = area_list.get_selected_items()
	if sel.is_empty():
		return
	var area: LDArea = _level().get_areas()[sel[0]]
	_level().rename_area(area, LDText.sanitize_edit(name_edit))
	LD.get_save_load_handler().save_session()
	area_list.set_item_text(sel[0], _label(area, sel[0]))

#endregion
