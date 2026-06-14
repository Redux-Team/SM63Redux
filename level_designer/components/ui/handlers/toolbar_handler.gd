class_name LDUIToolbarHandler
extends Node

## Editing toolbar: tool selection, clipboard/selection ops, z-order reordering, layer
## navigation, camera reset, and the group/tag picker buttons. Reached via
## LD.get_ui().get_toolbar_handler(). Button signals connect straight to these methods.

@export var _layer_num: Label


var _viewport: LDViewport:
	get():
		return LD.get_editor_viewport()


## Called by LDUI once the level designer is fully ready.
func setup() -> void:
	_refresh_layer_num()


# --- Tools ---------------------------------------------------------------------------

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


# --- Selection / clipboard -----------------------------------------------------------

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


# --- Group / tag pickers -------------------------------------------------------------

func _on_add_to_group_button_pressed() -> void:
	LD.get_ui().get_window_handler().open_group_picker("Add to Group", func(group_id: String) -> void:
		LD.get_object_handler().add_selection_to_group(group_id)
	)


func _on_remove_from_group_button_pressed() -> void:
	LD.get_ui().get_window_handler().open_group_picker("Remove from Group", func(group_id: String) -> void:
		LD.get_object_handler().remove_selection_from_group(group_id)
	)


func _on_add_to_tag_button_pressed() -> void:
	LD.get_ui().get_window_handler().open_tag_picker("Add to Tag", func(tag: String) -> void:
		LD.get_object_handler().add_selection_to_tag(tag)
	)


func _on_remove_from_tag_button_pressed() -> void:
	LD.get_ui().get_window_handler().open_tag_picker("Remove from Tag", func(tag: String) -> void:
		LD.get_object_handler().remove_selection_from_tag(tag)
	)


# --- Camera / layers -----------------------------------------------------------------

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
