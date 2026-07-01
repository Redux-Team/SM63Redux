class_name LDUIToolbarHandler
extends Node

## Editing toolbar: tool selection, clipboard/selection ops, z-order reordering, camera reset,
## active-layer navigation, and the stamp/tag buttons. Layers are created/renamed/reordered in the
## Layers window. Reached via LD.get_ui().get_toolbar_handler(). Button signals connect to these.

## Shows the active layer's name (or "Layer <index>") between the prev/next buttons.
@export var _layer_name_label: Label
@export var _prev_layer_button: Button
@export var _next_layer_button: Button


var _viewport: LDViewport:
	get():
		return LD.get_editor_viewport()


## Called by LDUI once the level designer is fully ready.
func setup() -> void:
	LDLevel._inst.active_area_changed.connect(_bind_area)
	_bind_area(LD.get_area())


## Keeps the active-layer label tracking whichever area is active.
func _bind_area(area: LDArea) -> void:
	if not area.active_layer_changed.is_connected(_on_active_layer_changed):
		area.active_layer_changed.connect(_on_active_layer_changed)
	if not area.layers_changed.is_connected(_refresh_layer_label):
		area.layers_changed.connect(_refresh_layer_label)
	_refresh_layer_label()


func _on_active_layer_changed(_index: int) -> void:
	_refresh_layer_label()


#region Tools

func _on_select_button_pressed() -> void:
	LD.get_tool_handler().select_tool("select")


func _on_brush_button_pressed() -> void:
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	var tool_name: String = obj.get_placement_tool() if obj else ""
	LD.get_tool_handler().select_tool(tool_name if not tool_name.is_empty() else "brush")


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


func _on_topline_pressed() -> void:
	LD.get_tool_handler().select_tool("topline")

#endregion


#region History

func _on_undo_button_pressed() -> void:
	LD.get_history_handler().undo()


func _on_redo_button_pressed() -> void:
	LD.get_history_handler().redo()

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
	open_create_stamp_dialog()


## Opens the "Create Stamp" name dialog for the current selection. Public so the stamp
## editor's "Create from Selection" button can reuse it. No-op if nothing is selected.
func open_create_stamp_dialog() -> void:
	if LD.get_object_handler().get_placed_selection().is_empty():
		return
	var existing: Array[String] = []
	for stamp: LDStamp in LD.get_stamp_handler().get_all_stamps():
		existing.append(stamp.id)
	_open_name_dialog("Create Stamp", "Create", LD.get_stamp_handler().suggest_stamp_id(),
		existing, "Or replace existing:", func(name: String) -> void:
			LD.get_object_handler().create_stamp_from_selection(name)
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
	# Only take/release priority if the UI doesn't already hold it (e.g. a window is open),
	# otherwise closing this dialog would hand input back to the viewport too early.
	if not LD.get_input_handler().has_input_priority(LD.get_ui()):
		LD.get_input_handler().set_input_priority(LD.get_ui())
		dialog.tree_exited.connect(func() -> void:
			LD.get_input_handler().remove_input_priority(LD.get_ui())
		)
	dialog.popup_centered()

#endregion


#region Camera / layers

func _on_reset_cam_button_pressed() -> void:
	# Search every layer of the active area (the player isn't always on layer 0), and never crash
	# if the area has no player.
	var player: LDObject = null
	for obj: LDObject in LD.get_area().get_all_objects():
		if obj.source_object_id == "player_mario":
			player = obj
			break
	var target: Vector2 = player.position if player else Vector2.ZERO
	_viewport.refocus_camera(target, Vector2.ONE)


func _on_prev_layer_pressed() -> void:
	_step_existing_layer(-1)


func _on_next_layer_pressed() -> void:
	_step_existing_layer(1)


## Moves the active layer to the previous/next existing layer (without creating new ones).
func _step_existing_layer(delta: int) -> void:
	var area: LDArea = LD.get_area()
	var pos: int = -1
	for i: int in area.layers.size():
		if area.layers[i].index == area.get_active_layer_index():
			pos = i
			break
	var target: int = clampi(pos + delta, 0, area.layers.size() - 1)
	if target != pos:
		LD.get_editor_viewport().navigate_active_layer(area.layers[target].index)


func _refresh_layer_label() -> void:
	var area: LDArea = LD.get_area()
	var active: int = area.get_active_layer_index()
	var anchor: int = area.get_player_layer_index()
	var pos: int = -1
	for i: int in area.layers.size():
		if area.layers[i].index == active:
			pos = i
			var layer: LDLayer = area.layers[i]
			_layer_name_label.text = layer.layer_name if not layer.layer_name.is_empty() else "Layer %d" % (layer.index - anchor)
	_prev_layer_button.disabled = pos <= 0
	GDSS.refresh(_prev_layer_button)
	_next_layer_button.disabled = pos < 0 or pos >= area.layers.size() - 1
	GDSS.refresh(_next_layer_button)

#endregion
