class_name LDToolHandler
extends Node

## Emitted whenever the active tool changes. Carries the new tool's get_tool_name()
## (empty string if nothing is selected). The UI chrome listens to this to highlight
## the active tool button.
signal tool_changed(tool_name: String)

var _selected_tool: LDTool
var _bound_tools: Dictionary[String, LDTool]


func setup() -> void:
	select_tool("select")


## The one spelling a tool is keyed and looked up by: case and underscores are both ignored, so
## "PolygonEdit", "polygon_edit" and "Polygon_Edit" all name the same tool.
static func normalize_tool_name(tool_name: String) -> String:
	return tool_name.to_lower().remove_char(95)


func get_selected_tool() -> LDTool:
	return _selected_tool


func get_tool(tool_name: String) -> LDTool:
	return _bound_tools.get(normalize_tool_name(tool_name))


func get_tool_list() -> Array[LDTool]:
	return _bound_tools.values()


## Switches tools, by name or by reference. The new tool is seated before the old one is torn down,
## so a [method LDTool._on_disable] or [method LDTool._on_enable] that selects a tool of its own
## wins: the outer call sees the selection has moved on and leaves it alone rather than enabling a
## second tool on top of it.
func select_tool(tool_name_or_ref: Variant) -> void:
	var next: LDTool = null
	if tool_name_or_ref is String:
		next = get_tool(tool_name_or_ref)
	elif tool_name_or_ref is LDTool and tool_name_or_ref in _bound_tools.values():
		next = tool_name_or_ref
	
	if next == _selected_tool:
		return
	
	var previous: LDTool = _selected_tool
	_selected_tool = next
	
	if previous and previous._enabled:
		previous._enabled = false
		previous._on_disable()
	if _selected_tool != next:
		return
	
	if next:
		next._enabled = true
		next._on_enable()
	if _selected_tool != next:
		return
	
	tool_changed.emit(next.get_tool_name() if next else "")


func add_tool(tool: LDTool) -> void:
	if tool not in get_children():
		if tool.get_parent():
			tool.reparent.call_deferred(self)
		else:
			add_child(tool)
	
	_bound_tools.set(normalize_tool_name(tool.get_tool_name()), tool)
