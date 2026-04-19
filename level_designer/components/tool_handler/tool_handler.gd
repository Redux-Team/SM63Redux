class_name LDToolHandler
extends LDComponent

var _selected_tool: LDTool
var _bound_tools: Dictionary[String, LDTool]


func _on_ready() -> void:
	select_tool("select")


func get_selected_tool() -> LDTool:
	return _selected_tool


func get_tool_list() -> Array[LDTool]:
	return _bound_tools.values()


func select_tool(tool_name_or_ref: Variant) -> void:
	if _selected_tool:
		_selected_tool._on_disable()
	
	if tool_name_or_ref is String:
		_selected_tool = _bound_tools.get(tool_name_or_ref.to_lower().remove_char(95))
	elif tool_name_or_ref is LDTool and tool_name_or_ref in _bound_tools.values():
		_selected_tool = tool_name_or_ref
	
	if _selected_tool:
		_selected_tool._on_enable()


func add_tool(tool: LDTool) -> void:
	if tool not in get_children():
		if tool.get_parent():
			tool.reparent.call_deferred(self)
		else:
			add_child(tool)
	
	_bound_tools.set(tool.get_tool_name().to_lower(), tool)
