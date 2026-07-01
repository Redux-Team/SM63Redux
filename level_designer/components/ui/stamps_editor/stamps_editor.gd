class_name LDStampEditor
extends MarginContainer


const ROW_CLASS: StringName = &"ListRow"
const STAMP_META: StringName = &"stamp"
const IID_META: StringName = &"iid"


@export var row_container: VBoxContainer
@export var count_label: Label
@export var create_button: Button
@export var remove_button: Button

@export var detail_content: VBoxContainer
@export var empty_center: Control
@export var name_edit: LineEdit
@export var indexable_check: CheckButton
@export var preview_rect: TextureRect
@export var replace_button: Button
@export var instances_label: Label
@export var instance_row_container: VBoxContainer
@export var remove_instance_button: Button


var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()
var _instance_rows: Array[Button] = []
var _instance_group: ButtonGroup = ButtonGroup.new()
var _selected_stamp: LDStamp = null
var _selected_instance_id: String = ""
var _setting_fields: bool = false


func _ready() -> void:
	create_button.pressed.connect(_on_create_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	replace_button.pressed.connect(_on_replace_pressed)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_on_name_focus_exited)
	indexable_check.toggled.connect(_on_indexable_toggled)
	remove_instance_button.pressed.connect(_on_remove_instance_pressed)
	
	var sh: LDStampHandler = LD.get_stamp_handler()
	sh.stamp_added.connect(_on_stamp_event_added)
	sh.stamp_removed.connect(_on_stamp_removed)
	sh.stamp_changed.connect(_on_stamp_changed)
	sh.instance_placed.connect(_on_instance_event)
	sh.instance_removed.connect(_on_instance_event)
	
	_refresh_stamp_list()


func _on_show() -> void:
	# Connect here (not _ready): this content is instantiated before the level exists. The instance
	# list is per-area, so refresh it when the active area changes (e.g. via the area spinbox).
	if LDLevel._inst and not LDLevel._inst.active_area_changed.is_connected(_on_active_area_changed):
		LDLevel._inst.active_area_changed.connect(_on_active_area_changed)
	var viewport: LDViewport = LD.get_editor_viewport()
	if viewport and not viewport.selection_changed.is_connected(_on_selection_changed):
		viewport.selection_changed.connect(_on_selection_changed)
	_refresh_stamp_list()


func _on_active_area_changed(_area: LDArea) -> void:
	_refresh_instance_list()


func _on_selection_changed(_objects: Array[LDObject]) -> void:
	_update_actions()


func _update_actions() -> void:
	var has_selection: bool = LDLevel._inst != null and not LD.get_object_handler().get_placed_selection().is_empty()
	create_button.disabled = not has_selection
	GDSS.refresh(create_button)
	replace_button.disabled = not has_selection or _selected_stamp == null
	GDSS.refresh(replace_button)


#region Stamp list

func _refresh_stamp_list() -> void:
	var prev_id: String = _selected_stamp.id if _selected_stamp else ""
	_clear_rows()
	
	var stamps: Array[LDStamp] = LD.get_stamp_handler().get_all_stamps()
	stamps.sort_custom(func(a: LDStamp, b: LDStamp) -> bool:
		return a.id < b.id
	)
	for stamp: LDStamp in stamps:
		var row: Button = _make_row(stamp.id, _row_group)
		row.set_meta(STAMP_META, stamp.id)
		row_container.add_child(row)
		row.pressed.connect(_on_stamp_row_pressed.bind(stamp.id))
		_rows.append(row)
	
	var noun: String = "stamp" if stamps.size() == 1 else "stamps"
	count_label.text = "%d %s" % [stamps.size(), noun]
	
	if not prev_id.is_empty():
		for row: Button in _rows:
			if str(row.get_meta(STAMP_META)) == prev_id:
				row.button_pressed = true
				_show_detail(LD.get_stamp_handler().get_stamp(prev_id))
				return
	
	_show_detail(null)


func _make_row(text: String, group: ButtonGroup) -> Button:
	var row: Button = Button.new()
	row.text = text
	row.toggle_mode = true
	row.button_group = group
	row.focus_mode = Control.FOCUS_NONE
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	row.set_meta(&"gdss_classes", PackedStringArray([ROW_CLASS]))
	return row


func _clear_rows() -> void:
	for row: Button in _rows:
		row.button_group = null
		row_container.remove_child(row)
		row.queue_free()
	_rows.clear()


func _on_stamp_row_pressed(id: String) -> void:
	_show_detail(LD.get_stamp_handler().get_stamp(id))


func _on_create_pressed() -> void:
	LD.get_ui().get_toolbar_handler().open_create_stamp_dialog()


func _on_remove_pressed() -> void:
	if not _selected_stamp:
		return
	var stamp_id: String = _selected_stamp.id
	if LD.get_stamp_handler().has_instances(stamp_id):
		_prompt_remove_with_instances(stamp_id)
	else:
		LD.get_stamp_handler().remove_stamp(stamp_id)


## When a stamp still has placed instances, let the user choose what happens to them:
## delete them along with the stamp, instantiate (detach) them into normal objects, or
## cancel and keep the stamp.
func _prompt_remove_with_instances(stamp_id: String) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Remove Stamp - " + stamp_id
	dialog.dialog_text = "This stamp still has placed instances.\nWhat should happen to them?"
	dialog.ok_button_text = "Delete Instances"
	dialog.add_button("Instantiate", true, "instantiate")
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func() -> void:
		LD.get_stamp_handler().remove_stamp(stamp_id)
		dialog.queue_free()
	)
	dialog.custom_action.connect(func(action: StringName) -> void:
		if action == &"instantiate":
			LD.get_stamp_handler().bake_stamp(stamp_id)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)

#endregion


#region Detail

func _show_detail(stamp: LDStamp) -> void:
	_selected_stamp = stamp
	_selected_instance_id = ""
	
	var has_stamp: bool = stamp != null
	empty_center.visible = not has_stamp
	detail_content.visible = has_stamp
	remove_button.disabled = not has_stamp
	GDSS.refresh(remove_button)
	if not has_stamp:
		_clear_instance_rows()
		_update_actions()
		return
	
	_setting_fields = true
	name_edit.text = stamp.id
	indexable_check.button_pressed = stamp.indexable
	_setting_fields = false
	
	preview_rect.texture = stamp.preview_texture
	_refresh_instance_list()
	_update_actions()


func _on_name_submitted(new_text: String) -> void:
	_try_rename(new_text)
	name_edit.release_focus()


func _on_name_focus_exited() -> void:
	if not _setting_fields:
		_try_rename(name_edit.text)


func _try_rename(new_name: String) -> void:
	if not _selected_stamp:
		return
	
	var cleaned: String = LDText.sanitize_name(new_name).strip_edges()
	if cleaned.is_empty() or cleaned == _selected_stamp.id:
		name_edit.text = _selected_stamp.id
		return
	
	if not LD.get_stamp_handler().rename_stamp(_selected_stamp.id, cleaned):
		name_edit.text = _selected_stamp.id


func _on_indexable_toggled(pressed: bool) -> void:
	if _setting_fields or not _selected_stamp:
		return
	LD.get_stamp_handler().set_indexable(_selected_stamp.id, pressed)


func _on_replace_pressed() -> void:
	if not _selected_stamp:
		return
	var objects: Array[LDObject] = LD.get_object_handler().get_placed_selection()
	if objects.is_empty():
		return
	var stamp_id: String = _selected_stamp.id
	if LD.get_stamp_handler().has_instances(stamp_id):
		_prompt_replace(stamp_id, objects)
	else:
		LD.get_stamp_handler().create_stamp_from_objects(objects, stamp_id)


func _prompt_replace(stamp_id: String, objects: Array[LDObject]) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "Replace Stamp - " + stamp_id
	dialog.dialog_text = "Replace this stamp's contents with the current selection?\nEvery placed instance will be rebuilt."
	dialog.ok_button_text = "Replace"
	add_child(dialog)
	dialog.popup_centered()
	
	dialog.confirmed.connect(func() -> void:
		LD.get_stamp_handler().create_stamp_from_objects(objects, stamp_id)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)

#endregion


#region Instances

## Lists only the active area's instances of the selected stamp - each area's placements are
## independent.
func _refresh_instance_list() -> void:
	_clear_instance_rows()
	_selected_instance_id = ""
	remove_instance_button.disabled = true
	GDSS.refresh(remove_instance_button)
	if not _selected_stamp:
		instances_label.text = "Instances in this area"
		return
	
	var area_name: String = LDLevel.get_active_area().area_name
	var area_instances: Array = _selected_stamp.get_area_instances(area_name)
	instances_label.text = "Instances in this area (%d)" % area_instances.size()
	for instance: Dictionary in area_instances:
		var unique_id: String = str(instance.get("unique_id", ""))
		var pos: Vector2 = Packer.array_to_vec2(instance.get("position", [0.0, 0.0]))
		var row: Button = _make_row("%s  (%d, %d)" % [unique_id, int(pos.x), int(pos.y)], _instance_group)
		row.set_meta(IID_META, unique_id)
		instance_row_container.add_child(row)
		row.pressed.connect(_on_instance_row_pressed.bind(unique_id))
		row.gui_input.connect(_on_instance_row_input.bind(unique_id))
		_instance_rows.append(row)


func _clear_instance_rows() -> void:
	for row: Button in _instance_rows:
		row.button_group = null
		instance_row_container.remove_child(row)
		row.queue_free()
	_instance_rows.clear()


func _on_instance_row_pressed(unique_id: String) -> void:
	_selected_instance_id = unique_id
	remove_instance_button.disabled = false
	GDSS.refresh(remove_instance_button)


## Double-clicking an instance focuses the editor camera on it (it's always in the active area, since
## the list only shows this area's instances).
func _on_instance_row_input(event: InputEvent, unique_id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if not button.double_click or button.button_index != MOUSE_BUTTON_LEFT:
		return
	var instance: Dictionary = _selected_stamp.get_instance(LDLevel.get_active_area().area_name, unique_id)
	if instance.is_empty():
		return
	# refocus_camera (not a raw camera_position set) so the grid shader and anchors refresh.
	LD.get_editor_viewport().refocus_camera(Packer.array_to_vec2(instance.get("position", [0.0, 0.0])))


func _on_remove_instance_pressed() -> void:
	if not _selected_stamp or _selected_instance_id.is_empty():
		return
	LD.get_stamp_handler().remove_instance(_selected_stamp.id, LDLevel.get_active_area().area_name, _selected_instance_id)
	_selected_instance_id = ""
	remove_instance_button.disabled = true
	GDSS.refresh(remove_instance_button)

#endregion


#region Handler events

func _on_stamp_event_added(_stamp: LDStamp) -> void:
	_refresh_stamp_list()


func _on_stamp_removed(stamp_id: String) -> void:
	if _selected_stamp and _selected_stamp.id == stamp_id:
		_show_detail(null)
	_refresh_stamp_list()


func _on_stamp_changed(_stamp: LDStamp) -> void:
	_refresh_stamp_list()


func _on_instance_event(stamp: LDStamp, _unique_id: String) -> void:
	if _selected_stamp and _selected_stamp.id == stamp.id:
		_refresh_instance_list()

#endregion
