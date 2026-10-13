class_name LDToolHandler
extends LDHandler

signal tool_changed(tool: LDTool)
signal armed_changed(entry: ObjectRegistry.Entry)

@export var default_tool: LDTool

var active_tool: LDTool
var armed: ObjectRegistry.Entry


func _setup() -> void:
	for tool: LDTool in get_tools():
		if tool.button:
			tool.button.pressed.connect(set_tool.bind(tool))
	
	set_tool(default_tool)


func _unhandled_input(event: InputEvent) -> void:
	if editor.is_shortcut(event, &"ld_tool_next") or editor.is_shortcut(event, &"ld_tool_previous"):
		cycle_tool(1 if event.is_action(&"ld_tool_next") else -1)
		get_viewport().set_input_as_handled()
		return
	
	for tool: LDTool in get_tools():
		if not tool.action.is_empty() and editor.is_shortcut(event, tool.action):
			set_tool(tool)
			get_viewport().set_input_as_handled()
			return


func get_tools() -> Array[LDTool]:
	var tools: Array[LDTool] = []
	for component: LDComponent in get_components():
		if component is LDTool:
			tools.append(component)
	
	return tools


func set_tool(tool: LDTool) -> void:
	if tool != active_tool:
		if active_tool:
			active_tool._deactivate()
		active_tool = tool
		active_tool._activate()
		tool_changed.emit(tool)
	
	for other: LDTool in get_tools():
		LD.set_active(other.button, other == active_tool)


func arm(entry: ObjectRegistry.Entry) -> void:
	armed = entry
	armed_changed.emit(entry)
	if active_tool.shape_kinds.has(entry.get_shape_kind()):
		return
	
	var tool: LDTool = get_placement_tool(entry)
	if tool:
		set_tool(tool)


func get_placement_tool(entry: ObjectRegistry.Entry) -> LDTool:
	var kind: ObjectShape.Kind = entry.get_shape_kind()
	for tool: LDTool in get_tools():
		if tool.shape_kinds.has(kind):
			return tool
	
	return null


func cycle_tool(direction: int) -> void:
	var available: Array[LDTool] = get_tools().filter(func(tool: LDTool) -> bool: return tool.button and tool.button.is_visible_in_tree() and not tool.button.disabled)
	if available.is_empty():
		return
	
	set_tool(available.get(posmod(available.find(active_tool) + direction, available.size())))


func cancel() -> void:
	active_tool._cancel()


func handle_input(event: InputEvent, world_position: Vector2) -> bool:
	return active_tool._tool_input(event, world_position)
