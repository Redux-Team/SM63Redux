class_name LDTagEditor
extends MarginContainer

## Simple editor for the level's tags: a list on the left plus an add / rename / remove
## flow. Tags are pure labels - scenarios target them to enable/disable objects. Unlike
## stamps there are no instances, previews, or captured objects.


@export var tag_list: ItemList
@export var add_button: Button
@export var remove_button: Button
@export var empty_label: Label
@export var detail_content: VBoxContainer
@export var name_edit: LineEdit


var _selected_tag: String = ""
var _setting_fields: bool = false


func _ready() -> void:
	add_button.pressed.connect(_on_add_pressed)
	remove_button.pressed.connect(_on_remove_pressed)
	tag_list.item_selected.connect(_on_tag_selected)
	name_edit.text_submitted.connect(_on_name_submitted)
	name_edit.focus_exited.connect(_on_name_focus_exited)

	var th: LDTagHandler = LD.get_tag_handler()
	th.tag_added.connect(_on_tags_changed.unbind(1))
	th.tag_removed.connect(_on_tags_changed.unbind(1))
	th.tag_changed.connect(_on_tags_changed.unbind(1))

	_refresh_list()


func _on_show() -> void:
	_refresh_list()


func _on_tags_changed() -> void:
	_refresh_list()


func _refresh_list() -> void:
	var prev: String = _selected_tag
	tag_list.clear()
	for tag: String in LD.get_tag_handler().get_all_tags():
		tag_list.add_item(tag)
		tag_list.set_item_metadata(tag_list.item_count - 1, tag)

	if not prev.is_empty():
		for i: int in tag_list.item_count:
			if str(tag_list.get_item_metadata(i)) == prev:
				tag_list.select(i)
				_show_detail(prev)
				return
	_show_detail("")


func _show_detail(tag: String) -> void:
	_selected_tag = tag
	var has_tag: bool = not tag.is_empty()
	empty_label.visible = not has_tag
	detail_content.visible = has_tag
	remove_button.disabled = not has_tag
	if not has_tag:
		return
	_setting_fields = true
	name_edit.text = tag
	_setting_fields = false


func _on_tag_selected(index: int) -> void:
	_show_detail(str(tag_list.get_item_metadata(index)))


func _on_add_pressed() -> void:
	var th: LDTagHandler = LD.get_tag_handler()
	var id: String = "new_tag"
	var counter: int = 1
	while th.has_tag(id):
		id = "new_tag_" + str(counter)
		counter += 1

	th.create_tag(id)

	for i: int in tag_list.item_count:
		if str(tag_list.get_item_metadata(i)) == id:
			tag_list.select(i)
			_show_detail(id)
			name_edit.grab_focus()
			name_edit.select_all()
			return


func _on_remove_pressed() -> void:
	if _selected_tag.is_empty():
		return
	LD.get_tag_handler().remove_tag(_selected_tag)
	_selected_tag = ""


func _on_name_submitted(new_text: String) -> void:
	_try_rename(new_text)
	name_edit.release_focus()


func _on_name_focus_exited() -> void:
	if not _setting_fields:
		_try_rename(name_edit.text)


func _try_rename(new_name: String) -> void:
	if _selected_tag.is_empty():
		return
	var cleaned: String = new_name.strip_edges()
	if cleaned.is_empty() or cleaned == _selected_tag:
		name_edit.text = _selected_tag
		return
	if LD.get_tag_handler().rename_tag(_selected_tag, cleaned):
		_selected_tag = cleaned
	else:
		name_edit.text = _selected_tag
