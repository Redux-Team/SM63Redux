class_name LDBlockEdit
extends LDWidgetTool


func get_tool_name() -> String:
	return "BlockEdit"


func _get_target_objects() -> Array[LDObject]:
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and _is_block(selected.front()):
		return selected
	return []


func _input(event: InputEvent) -> void:
	if is_active() and event is InputEventKey:
		_widget.on_input(event)


func _is_block(obj: LDObject) -> bool:
	return obj != null and (obj.has_property(&"b_size_x") or obj.has_property(&"b_size_y"))
