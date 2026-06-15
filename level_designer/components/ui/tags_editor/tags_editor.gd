class_name LDTagEditor
extends MarginContainer

## Tags the current selection. The list shows the selection's tags - tags shared by every selected
## object plainly, and partially-applied ones with a "(count)" suffix (e.g. "Purple Coins (5)").
## Type a name to add a tag to the whole selection, or pick one and remove it. With nothing
## selected it just lists every tag in the level and how many objects use it.


@export var selection_label: Label
@export var tag_list: ItemList
@export var name_edit: LineEdit
@export var add_button: Button
@export var remove_button: Button


func _ready() -> void:
	add_button.pressed.connect(_on_add)
	name_edit.text_submitted.connect(func(_text: String) -> void: _on_add())
	remove_button.pressed.connect(_on_remove)
	tag_list.item_selected.connect(func(_index: int) -> void: _update_buttons())
	name_edit.text_changed.connect(func(_text: String) -> void: _update_buttons())

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
	tag_list.clear()

	var has_selection: bool = not selection.is_empty()
	remove_button.text = "Remove from Selection" if has_selection else "Delete Tag"

	if selection.is_empty():
		selection_label.text = "No selection - all tags"
		for tag: String in th.get_all_tags():
			_add_item(tag, th.get_objects_with_tag(tag).size(), -1)
	else:
		selection_label.text = "%d object%s selected" % [selection.size(), "" if selection.size() == 1 else "s"]
		# Count how many selected objects carry each tag.
		var counts: Dictionary[String, int] = {}
		for obj: LDObject in selection:
			for tag: String in th.get_object_tags(obj):
				counts[tag] = counts.get(tag, 0) + 1
		var tags: Array = counts.keys()
		tags.sort()
		# Tags shared by the whole selection first (shown plainly), then the partial ones.
		for tag: String in tags:
			if counts[tag] == selection.size():
				_add_item(tag, counts[tag], selection.size())
		for tag: String in tags:
			if counts[tag] < selection.size():
				_add_item(tag, counts[tag], selection.size())

	_update_buttons()


## Adds a list row: plain when it covers the whole selection, otherwise suffixed with the count.
func _add_item(tag: String, count: int, selection_size: int) -> void:
	var label: String = tag if (selection_size > 0 and count == selection_size) else "%s (%d)" % [tag, count]
	tag_list.add_item(label)
	tag_list.set_item_metadata(tag_list.item_count - 1, tag)


func _update_buttons() -> void:
	# Add/remove always work: with a selection they (un)tag those objects, otherwise they create or
	# delete the tag for the whole level.
	remove_button.disabled = tag_list.get_selected_items().is_empty()
	# Label the add action by what it'll do: type a name to make a new tag, or leave it empty and
	# pick a tag from the list to apply that existing one.
	if _selection().is_empty():
		add_button.text = "Create Tag"
	elif not name_edit.text.strip_edges().is_empty():
		add_button.text = "Create & Add Selection"
	elif not tag_list.get_selected_items().is_empty():
		add_button.text = "Add from Selection"
	else:
		add_button.text = "Add to Selection"


func _on_add() -> void:
	var selection: Array[LDObject] = _selection()
	var typed: String = name_edit.text.strip_edges()
	if selection.is_empty():
		if typed.is_empty() or typed.contains(":"):
			return
		LD.get_tag_handler().create_tag(typed)
		name_edit.clear()
		_refresh()
		return

	# With objects selected: a typed name creates and applies a tag, otherwise the picked list tag
	# is applied to the selection.
	var tag: String = typed
	if tag.is_empty():
		var selected_items: PackedInt32Array = tag_list.get_selected_items()
		if selected_items.is_empty():
			return
		tag = str(tag_list.get_item_metadata(selected_items[0]))
	elif tag.contains(":"):
		return
	LD.get_tag_handler().tag_objects(tag, selection)
	name_edit.clear()
	_refresh()


func _on_remove() -> void:
	var selected_items: PackedInt32Array = tag_list.get_selected_items()
	if selected_items.is_empty():
		return
	var tag: String = str(tag_list.get_item_metadata(selected_items[0]))
	var selection: Array[LDObject] = _selection()
	if selection.is_empty():
		LD.get_tag_handler().remove_tag(tag)
	else:
		LD.get_tag_handler().untag_objects(tag, selection)
	_refresh()
