class_name LDGroupEditor
extends MarginContainer


@export var group_list: ItemList
@export var add_button: Button
@export var remove_button: Button
@export var empty_label: Label
@export var detail_content: VBoxContainer
@export var name_edit: LineEdit
@export var preview_rect: TextureRect
@export var anchor_section: VBoxContainer
@export var anchor_list: ItemList
@export var add_anchor_button: Button
@export var remove_anchor_button: Button


var _selected_group: LDGroup = null
var _selected_anchor_id: String = ""
var _setting_fields: bool = false


func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	group_list.item_selected.connect(_on_group_selected)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_on_name_focus_exited)
	add_anchor_button.pressed.connect(_on_add_anchor_pressed)
	remove_anchor_button.pressed.connect(_on_remove_anchor_pressed)
	anchor_list.item_selected.connect(_on_anchor_selected)
	anchor_list.item_activated.connect(_on_anchor_activated)

	var gh: LDGroupHandler = LD.get_group_handler()
	gh.group_added.connect(_on_group_added)
	gh.group_removed.connect(_on_group_removed)
	gh.group_changed.connect(_on_group_changed)
	gh.anchor_placed.connect(_on_anchor_event)
	gh.anchor_removed.connect(_on_anchor_event)
	
	_refresh_group_list()


func _on_show() -> void:
	_refresh_group_list()


func _refresh_group_list() -> void:
	var prev_id: String = _selected_group.id if _selected_group else ""
	group_list.clear()
	
	var groups: Array[LDGroup] = LD.get_group_handler().get_all_groups()
	groups.sort_custom(func(a: LDGroup, b: LDGroup) -> bool:
		return a.id < b.id
	)
	
	for group: LDGroup in groups:
		group_list.add_item(group.id)
		group_list.set_item_metadata(group_list.item_count - 1, group.id)
	
	if prev_id.is_empty():
		_show_detail(null)
		return
	
	for i: int in group_list.item_count:
		if group_list.get_item_metadata(i) == prev_id:
			group_list.select(i)
			return
	
	_show_detail(null)


func _show_detail(group: LDGroup) -> void:
	_selected_group = group
	_selected_anchor_id = ""
	
	var has_group: bool = group != null
	empty_label.visible = not has_group
	detail_content.visible = has_group
	remove_button.disabled = not has_group
	
	if not has_group:
		return
	
	_setting_fields = true
	name_edit.text = group.id
	_setting_fields = false

	_refresh_detail()


func _refresh_detail() -> void:
	if not _selected_group:
		return

	preview_rect.texture = _selected_group.preview_texture
	anchor_section.visible = true
	_refresh_anchor_list()


func _refresh_anchor_list() -> void:
	anchor_list.clear()
	remove_anchor_button.disabled = true
	_selected_anchor_id = ""
	
	for i: int in _selected_group.anchors.size():
		var anchor: Dictionary = _selected_group.anchors[i]
		var unique_id: String = anchor.get("unique_id", "")
		var pos: Vector2 = Packer.array_to_vec2(anchor.get("position", [0.0, 0.0]))
		var primary: String = " ★" if i == 0 else ""
		anchor_list.add_item("%s%s  (%d, %d)" % [unique_id, primary, int(pos.x), int(pos.y)])
		anchor_list.set_item_metadata(anchor_list.item_count - 1, unique_id)


func _on_add_pressed() -> void:
	var gh: LDGroupHandler = LD.get_group_handler()
	var id: String = "new_group"
	var counter: int = 1
	while gh.has_group(id):
		id = "new_group_" + str(counter)
		counter += 1
	
	gh.create_group(id)
	
	for i: int in group_list.item_count:
		if group_list.get_item_metadata(i) == id:
			group_list.select(i)
			_show_detail(gh.get_group(id))
			name_edit.grab_focus()
			name_edit.select_all()
			return


func _on_remove_pressed() -> void:
	if not _selected_group:
		return
	LD.get_group_handler().remove_group(_selected_group.id)


func _on_group_selected(index: int) -> void:
	var id: String = group_list.get_item_metadata(index)
	_show_detail(LD.get_group_handler().get_group(id))


func _on_name_submitted(new_text: String) -> void:
	_try_rename(new_text)
	name_edit.release_focus()


func _on_name_focus_exited() -> void:
	if not _setting_fields:
		_try_rename(name_edit.text)


func _try_rename(new_name: String) -> void:
	if not _selected_group:
		return
	
	var cleaned: String = new_name.strip_edges()
	if cleaned.is_empty() or cleaned.contains(":") or cleaned == _selected_group.id:
		name_edit.text = _selected_group.id
		return
	
	if not LD.get_group_handler().rename_group(_selected_group.id, cleaned):
		name_edit.text = _selected_group.id


func _on_add_anchor_pressed() -> void:
	if not _selected_group:
		return
	
	var default_id: String = "anchor_" + str(_selected_group.anchors.size())
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = "New Anchor — " + _selected_group.id
	
	var vbox: VBoxContainer = VBoxContainer.new()
	var label: Label = Label.new()
	label.text = "Unique ID (no colons):"
	var line_edit: LineEdit = LineEdit.new()
	line_edit.text = default_id
	line_edit.placeholder_text = "e.g. left_side"
	vbox.add_child(label)
	vbox.add_child(line_edit)
	dialog.add_child(vbox)
	add_child(dialog)
	dialog.popup_centered()
	line_edit.grab_focus()
	line_edit.select_all()
	
	dialog.confirmed.connect(func() -> void:
		var unique_id: String = line_edit.text.strip_edges()
		if unique_id.is_empty() or unique_id.contains(":") or _selected_group.has_anchor(unique_id):
			dialog.queue_free()
			return
		var viewport: LDViewport = LD.get_editor_viewport()
		LD.get_group_handler().place_linked(
			_selected_group.id,
			unique_id,
			viewport.camera_position,
			LDLevel.get_active_area()._active_index
		)
		dialog.queue_free()
	)
	dialog.canceled.connect(func() -> void:
		dialog.queue_free()
	)


func _on_remove_anchor_pressed() -> void:
	if not _selected_group or _selected_anchor_id.is_empty():
		return
	LD.get_group_handler().remove_anchor(_selected_group.id, _selected_anchor_id)
	_selected_anchor_id = ""
	remove_anchor_button.disabled = true


func _on_anchor_selected(index: int) -> void:
	_selected_anchor_id = anchor_list.get_item_metadata(index)
	remove_anchor_button.disabled = false


func _on_anchor_activated(index: int) -> void:
	var unique_id: String = anchor_list.get_item_metadata(index)
	var anchor: Dictionary = _selected_group.get_anchor(unique_id)
	if anchor.is_empty():
		return
	LD.get_editor_viewport().camera_position = Packer.array_to_vec2(anchor.get("position", [0.0, 0.0]))


func _on_group_added(_group: LDGroup) -> void:
	_refresh_group_list()


func _on_group_removed(group_id: String) -> void:
	if _selected_group and _selected_group.id == group_id:
		_show_detail(null)
	_refresh_group_list()


func _on_group_changed(group: LDGroup) -> void:
	if _selected_group and _selected_group.id == group.id:
		_refresh_detail()
	_refresh_group_list()


func _on_anchor_event(group: LDGroup, _unique_id: String) -> void:
	if _selected_group and _selected_group.id == group.id:
		_refresh_anchor_list()
