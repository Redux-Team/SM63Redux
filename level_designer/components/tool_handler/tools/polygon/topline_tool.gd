extends LDWidgetTool


func get_tool_name() -> String:
	return "Topline"


## Edges belong to one shape at a time, so the tool only stands up against a single selected
## polygon and bounces back to Select for anything else.
func _get_target_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	var selected: Array[LDObject] = viewport.get_selected_objects()
	if selected.size() == 1 and selected.front() is LDObjectPolygon:
		result.append(selected.front())
	return result
