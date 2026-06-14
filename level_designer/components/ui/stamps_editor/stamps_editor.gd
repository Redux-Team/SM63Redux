class_name LDStampEditor
extends MarginContainer


@export var stamp_list: ItemList
@export var remove_button: Button
@export var empty_label: Label
@export var detail_content: VBoxContainer
@export var name_edit: LineEdit
@export var preview_rect: TextureRect
@export var anchor_section: VBoxContainer
@export var anchor_list: ItemList
@export var remove_anchor_button: Button


var _selected_stamp: LDStamp = null
var _selected_anchor_id: String = ""
var _setting_fields: bool = false


func _ready() -> void:
	remove_button.pressed.connect(_on_remove_pressed)
	stamp_list.item_selected.connect(_on_stamp_selected)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_on_name_focus_exited)
	remove_anchor_button.pressed.connect(_on_remove_anchor_pressed)
	anchor_list.item_selected.connect(_on_anchor_selected)
	anchor_list.item_activated.connect(_on_anchor_activated)

	var sh: LDStampHandler = LD.get_stamp_handler()
	sh.stamp_added.connect(_on_stamp_event_added)
	sh.stamp_removed.connect(_on_stamp_removed)
	sh.stamp_changed.connect(_on_stamp_changed)
	sh.anchor_placed.connect(_on_anchor_event)
	sh.anchor_removed.connect(_on_anchor_event)

	_refresh_stamp_list()


func _on_show() -> void:
	_refresh_stamp_list()


func _refresh_stamp_list() -> void:
	var prev_id: String = _selected_stamp.id if _selected_stamp else ""
	stamp_list.clear()

	var stamps: Array[LDStamp] = LD.get_stamp_handler().get_all_stamps()
	stamps.sort_custom(func(a: LDStamp, b: LDStamp) -> bool:
		return a.id < b.id
	)

	for stamp: LDStamp in stamps:
		stamp_list.add_item(stamp.id)
		stamp_list.set_item_metadata(stamp_list.item_count - 1, stamp.id)

	if prev_id.is_empty():
		_show_detail(null)
		return

	for i: int in stamp_list.item_count:
		if stamp_list.get_item_metadata(i) == prev_id:
			stamp_list.select(i)
			return

	_show_detail(null)


func _show_detail(stamp: LDStamp) -> void:
	_selected_stamp = stamp
	_selected_anchor_id = ""

	var has_stamp: bool = stamp != null
	empty_label.visible = not has_stamp
	detail_content.visible = has_stamp
	remove_button.disabled = not has_stamp

	if not has_stamp:
		return

	_setting_fields = true
	name_edit.text = stamp.id
	_setting_fields = false

	_refresh_detail()


func _refresh_detail() -> void:
	if not _selected_stamp:
		return

	preview_rect.texture = _selected_stamp.preview_texture
	anchor_section.visible = true
	_refresh_anchor_list()


func _refresh_anchor_list() -> void:
	anchor_list.clear()
	remove_anchor_button.disabled = true
	_selected_anchor_id = ""

	for i: int in _selected_stamp.anchors.size():
		var anchor: Dictionary = _selected_stamp.anchors[i]
		var unique_id: String = anchor.get("unique_id", "")
		var pos: Vector2 = Packer.array_to_vec2(anchor.get("position", [0.0, 0.0]))
		anchor_list.add_item("%s  (%d, %d)" % [unique_id, int(pos.x), int(pos.y)])
		anchor_list.set_item_metadata(anchor_list.item_count - 1, unique_id)


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


func _on_stamp_selected(index: int) -> void:
	var id: String = stamp_list.get_item_metadata(index)
	_show_detail(LD.get_stamp_handler().get_stamp(id))


func _on_name_submitted(new_text: String) -> void:
	_try_rename(new_text)
	name_edit.release_focus()


func _on_name_focus_exited() -> void:
	if not _setting_fields:
		_try_rename(name_edit.text)


func _try_rename(new_name: String) -> void:
	if not _selected_stamp:
		return

	var cleaned: String = new_name.strip_edges()
	if cleaned.is_empty() or cleaned.contains(":") or cleaned == _selected_stamp.id:
		name_edit.text = _selected_stamp.id
		return

	if not LD.get_stamp_handler().rename_stamp(_selected_stamp.id, cleaned):
		name_edit.text = _selected_stamp.id


func _on_remove_anchor_pressed() -> void:
	if not _selected_stamp or _selected_anchor_id.is_empty():
		return
	LD.get_stamp_handler().remove_anchor(_selected_stamp.id, _selected_anchor_id)
	_selected_anchor_id = ""
	remove_anchor_button.disabled = true


func _on_anchor_selected(index: int) -> void:
	_selected_anchor_id = anchor_list.get_item_metadata(index)
	remove_anchor_button.disabled = false


func _on_anchor_activated(index: int) -> void:
	var unique_id: String = anchor_list.get_item_metadata(index)
	var anchor: Dictionary = _selected_stamp.get_anchor(unique_id)
	if anchor.is_empty():
		return
	LD.get_editor_viewport().camera_position = Packer.array_to_vec2(anchor.get("position", [0.0, 0.0]))


func _on_stamp_event_added(_stamp: LDStamp) -> void:
	_refresh_stamp_list()


func _on_stamp_removed(stamp_id: String) -> void:
	if _selected_stamp and _selected_stamp.id == stamp_id:
		_show_detail(null)
	_refresh_stamp_list()


func _on_stamp_changed(stamp: LDStamp) -> void:
	if _selected_stamp and _selected_stamp.id == stamp.id:
		_refresh_detail()
	_refresh_stamp_list()


func _on_anchor_event(stamp: LDStamp, _unique_id: String) -> void:
	if _selected_stamp and _selected_stamp.id == stamp.id:
		_refresh_anchor_list()
