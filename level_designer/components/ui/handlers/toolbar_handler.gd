class_name LDUIToolbarHandler
extends Node

## Editing toolbar: tool selection, clipboard/selection ops, z-order reordering, layer
## navigation, camera reset, and the stamp/tag buttons. Reached via
## LD.get_ui().get_toolbar_handler(). Button signals connect straight to these methods.

@export var _layer_num: Label


var _viewport: LDViewport:
	get():
		return LD.get_editor_viewport()


## Called by LDUI once the level designer is fully ready.
func setup() -> void:
	_refresh_layer_num()


#region Tools

func _on_select_button_pressed() -> void:
	LD.get_tool_handler().select_tool("select")


func _on_brush_button_pressed() -> void:
	LD.get_tool_handler().select_tool("brush")


func _on_move_button_pressed() -> void:
	LD.get_tool_handler().select_tool("move")


func _on_rotate_button_pressed() -> void:
	LD.get_tool_handler().select_tool("rotate")


func _on_scale_button_pressed() -> void:
	LD.get_tool_handler().select_tool("scale")


func _on_place_button_pressed() -> void:
	LD.get_tool_handler().select_tool("place")


func _on_poly_edit_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_edit")


func _on_poly_add_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_add")


func _on_poly_cut_pressed() -> void:
	LD.get_tool_handler().select_tool("polygon_cut")

#endregion


#region Selection / clipboard

func _on_delete_button_pressed() -> void:
	LD.get_object_handler().delete_placed_selection()


func _on_deselect_button_pressed() -> void:
	_viewport.clear_selection()


func _on_cut_button_pressed() -> void:
	LD.get_clipboard_handler().cut()


func _on_copy_button_pressed() -> void:
	LD.get_clipboard_handler().copy()


func _on_paste_button_pressed() -> void:
	const OFFSET: Vector2 = Vector2(24, -24)
	LD.get_clipboard_handler().paste_absolute(_viewport.camera_position + OFFSET)


func _on_duplicate_button_pressed() -> void:
	LD.get_clipboard_handler().duplicate_objects()


func _on_move_to_front_button_pressed() -> void:
	for obj: LDObject in _viewport.get_selected_objects():
		obj.get_parent().move_child(obj, -1)


func _on_move_to_back_button_pressed() -> void:
	for obj: LDObject in _viewport.get_selected_objects():
		obj.get_parent().move_child(obj, 0)

#endregion


#region Stamps / tags

## Snapshots the selection into a stamp. The name field is prefilled; picking an existing
## stamp instead overwrites it.
func _on_create_stamp_button_pressed() -> void:
	if LD.get_object_handler().get_placed_selection().is_empty():
		return
	var existing: Array[String] = []
	for stamp: LDStamp in LD.get_stamp_handler().get_all_stamps():
		existing.append(stamp.id)
	_open_name_dialog("Create Stamp", "Create", LD.get_stamp_handler().suggest_stamp_id(),
		existing, "Or replace existing:", func(name: String) -> void:
			LD.get_object_handler().create_stamp_from_selection(name)
	)


## Tags the selection. Type a new tag name or pick an existing one.
func _on_add_to_tag_button_pressed() -> void:
	if LD.get_object_handler().get_placed_selection().is_empty():
		return
	_open_name_dialog("Add Tag", "Add", "", LD.get_tag_handler().get_all_tags(),
		"Or pick existing:", func(name: String) -> void:
			LD.get_object_handler().add_selection_to_tag(name)
	)


func _on_remove_from_tag_button_pressed() -> void:
	LD.get_ui().get_window_handler().open_tag_picker("Remove from Tag", func(tag: String) -> void:
		LD.get_object_handler().remove_selection_from_tag(tag)
	)


## Shared "name or pick existing" dialog used by Create Stamp / Add Tag. Calls on_confirm
## with the chosen name. Holds editor input while open so typing can't pan the viewport.
func _open_name_dialog(title: String, ok_text: String, default_name: String, existing: Array[String], pick_label_text: String, on_confirm: Callable) -> void:
	var dialog: ConfirmationDialog = ConfirmationDialog.new()
	dialog.title = title
	dialog.ok_button_text = ok_text

	var vbox: VBoxContainer = VBoxContainer.new()
	var name_label: Label = Label.new()
	name_label.text = "Name:"
	var name_edit: LineEdit = LineEdit.new()
	name_edit.text = default_name
	var pick_label: Label = Label.new()
	pick_label.text = pick_label_text
	var pick: OptionButton = OptionButton.new()
	pick.add_item("(New)")
	pick.set_item_metadata(0, "")
	for id: String in existing:
		pick.add_item(id)
		pick.set_item_metadata(pick.item_count - 1, id)

	# Picking an existing entry fills + locks the name field.
	pick.item_selected.connect(func(idx: int) -> void:
		var picked: String = str(pick.get_item_metadata(idx))
		if not picked.is_empty():
			name_edit.text = picked
		name_edit.editable = picked.is_empty()
	)

	vbox.add_child(name_label)
	vbox.add_child(name_edit)
	vbox.add_child(pick_label)
	vbox.add_child(pick)
	dialog.add_child(vbox)

	dialog.confirmed.connect(func() -> void:
		var picked: String = str(pick.get_item_metadata(pick.selected))
		var chosen: String = picked if not picked.is_empty() else name_edit.text.strip_edges()
		if not chosen.is_empty() and not chosen.contains(":"):
			on_confirm.call(chosen)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)

	_open_input_locked_dialog(dialog)
	name_edit.grab_focus()
	name_edit.select_all()


## Pops a dialog while taking editor input priority, so keyboard typing (e.g. WASD in a
## name field) can't drive the viewport. Priority is released when the dialog leaves.
func _open_input_locked_dialog(dialog: Window) -> void:
	add_child(dialog)
	LD.get_input_handler().set_input_priority(LD.get_ui())
	dialog.tree_exited.connect(func() -> void:
		LD.get_input_handler().remove_input_priority(LD.get_ui())
	)
	dialog.popup_centered()

#endregion


#region Camera / layers

func _on_reset_cam_button_pressed() -> void:
	var player: LDObject = LD.get_area().find_object_by_id("player_mario", 0)
	_viewport.refocus_camera(player.position, Vector2.ONE)


func _on_layer_down_pressed() -> void:
	_set_layer(-1)


func _on_layer_up_pressed() -> void:
	_set_layer(1)


func _set_layer(index: int) -> void:
	LD.get_area().set_active_layer(LD.get_area().get_active_layer_index() + index)
	if _viewport.get_selected_objects().size() > 0:
		LD.get_area().move_objects_to_layer(_viewport.get_selected_objects(), index)
	_refresh_layer_num()


func _refresh_layer_num() -> void:
	_layer_num.text = str(LD.get_area().get_active_layer_index())

#endregion
