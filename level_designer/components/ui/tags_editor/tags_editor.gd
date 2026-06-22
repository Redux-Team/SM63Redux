class_name LDTagEditor
extends MarginContainer


const ROW_CLASS: StringName = &"ListRow"
const TAG_META: StringName = &"tag"
const COUNT_META: StringName = &"count"


@export var selection_label: Label
@export var row_container: VBoxContainer
@export var name_edit: LineEdit
@export var create_button: Button
@export var delete_button: Button
@export var selection_actions: Control
@export var add_selection_button: Button
@export var remove_selection_button: Button


var _rows: Array[Button] = []
var _row_group: ButtonGroup = ButtonGroup.new()


func _ready() -> void:
	create_button.pressed.connect(_on_create)
	delete_button.pressed.connect(_on_delete)
	add_selection_button.pressed.connect(_on_add_selection)
	remove_selection_button.pressed.connect(_on_remove_selection)
	name_edit.text_changed.connect(func(_text: String) -> void: _update_buttons())
	name_edit.text_submitted.connect(func(_text: String) -> void: _on_create())
	
	var th: LDTagHandler = LD.get_tag_handler()
	th.tag_added.connect(_refresh.unbind(1))
	th.tag_removed.connect(_refresh.unbind(1))
	th.tag_changed.connect(_refresh.unbind(1))
	
	_refresh()


func _on_show() -> void:
	_refresh()


func _selection() -> Array[LDObject]:
	return LD.get_object_handler().get_placed_selection()


func _refresh() -> void:
	var th: LDTagHandler = LD.get_tag_handler()
	var selection: Array[LDObject] = _selection()
	var keep: String = _selected_tag()
	_clear_rows()
	var all_tags: Array = th.get_all_tags().duplicate()
	all_tags.sort()
	
	if selection.is_empty():
		selection_label.text = "All tags in level"
		for tag: String in all_tags:
			_add_item(tag, th.get_objects_with_tag(tag).size())
	else:
		selection_label.text = "%d object%s selected" % [selection.size(), "" if selection.size() == 1 else "s"]
		var counts: Dictionary[String, int] = {}
		for obj: LDObject in selection:
			for tag: String in th.get_object_tags(obj):
				counts[tag] = counts.get(tag, 0) + 1
		for tag: String in all_tags:
			if counts.get(tag, 0) > 0:
				_add_item(tag, counts[tag])
		for tag: String in all_tags:
			if counts.get(tag, 0) == 0:
				_add_item(tag, 0)
	
	if not keep.is_empty():
		for row: Button in _rows:
			if str(row.get_meta(TAG_META)) == keep:
				row.button_pressed = true
				break
	
	_update_buttons()


func _add_item(tag: String, count: int) -> void:
	var row: Button = _make_row("%s (%d)" % [tag, count])
	row.set_meta(TAG_META, tag)
	row.set_meta(COUNT_META, count)
	row_container.add_child(row)
	row.pressed.connect(_update_buttons)
	_rows.append(row)


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
		row_container.remove_child(row)
		row.queue_free()
	_rows.clear()


func _selected_tag() -> String:
	for row: Button in _rows:
		if row.button_pressed:
			return str(row.get_meta(TAG_META))
	return ""


func _selected_count() -> int:
	for row: Button in _rows:
		if row.button_pressed:
			return int(row.get_meta(COUNT_META, 0))
	return 0


func _update_buttons() -> void:
	var selection: Array[LDObject] = _selection()
	var has_selection: bool = not selection.is_empty()
	var picked: bool = not _selected_tag().is_empty()
	create_button.disabled = name_edit.text.strip_edges().is_empty()
	GDSS.refresh(create_button)
	delete_button.disabled = not picked
	GDSS.refresh(delete_button)
	selection_actions.visible = has_selection
	if has_selection:
		var count: int = _selected_count()
		add_selection_button.disabled = not picked or count >= selection.size()
		GDSS.refresh(add_selection_button)
		remove_selection_button.disabled = not picked or count <= 0
		GDSS.refresh(remove_selection_button)


func _on_create() -> void:
	var typed: String = LDText.sanitize_name(name_edit.text).strip_edges()
	if typed.is_empty() or typed.contains(":"):
		return
	LD.get_tag_handler().create_tag(typed)
	name_edit.clear()
	_refresh()


func _on_add_selection() -> void:
	var tag: String = _selected_tag()
	var selection: Array[LDObject] = _selection()
	if tag.is_empty() or selection.is_empty():
		return
	LD.get_tag_handler().tag_objects(tag, selection)
	_refresh()


func _on_remove_selection() -> void:
	var tag: String = _selected_tag()
	var selection: Array[LDObject] = _selection()
	if tag.is_empty() or selection.is_empty():
		return
	LD.get_tag_handler().untag_objects(tag, selection)
	_refresh()


func _on_delete() -> void:
	var tag: String = _selected_tag()
	if tag.is_empty():
		return
	LD.get_tag_handler().remove_tag(tag)
	_refresh()
