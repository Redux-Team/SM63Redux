class_name LDToolHandler
extends LDHandler

signal tool_changed(tool: LDTool)
signal armed_changed(entry: ObjectRegistry.Entry)

const ROTATION_KEY: StringName = &"@rotation"
const SCALE_KEY: StringName = &"@scale"

@export var default_tool: LDTool

var active_tool: LDTool
var armed: ObjectRegistry.Entry
var placement_values: Dictionary = {}
var _last_subtool: Dictionary[BaseButton, LDTool] = {}


func _setup() -> void:
	var buttons: Array[BaseButton] = []
	for tool: LDTool in get_tools():
		for button: BaseButton in [tool.button, tool.group_button]:
			if button and not buttons.has(button):
				buttons.append(button)
				button.pressed.connect(_on_button_pressed.bind(button))
	
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
		if not tool.shape_kinds.is_empty() or tool is LDBrushTool:
			editor.object_handler.selection.clear()
		active_tool._activate()
		if tool.group_button:
			_last_subtool.set(tool.group_button, tool)
		tool_changed.emit(tool)
	
	var highlighted: BaseButton = active_tool.button if active_tool.button else default_tool.button
	for other: LDTool in get_tools():
		LD.set_active(other.button, other.button == highlighted or other.button == active_tool.group_button)


func arm(entry: ObjectRegistry.Entry, values: Dictionary = {}) -> void:
	armed = entry
	placement_values = values
	armed_changed.emit(entry)
	if active_tool.shape_kinds.has(entry.get_shape_kind()):
		return
	
	var tool: LDTool = get_placement_tool(entry)
	if tool:
		set_tool(tool)


func should_randomize(property: ObjectProperty) -> bool:
	return property.randomize_on_place and not placement_values.has(property.key)


func matches_placement(object: GameObject) -> bool:
	for property: ObjectProperty in object.properties:
		if should_randomize(property):
			continue
		
		if object.get_value(property.key) != placement_values.get(property.key, property.coerce(null)):
			return false
	
	return true


func apply_placement_values(data: ObjectData) -> void:
	if armed == null or data.id != armed.id:
		return
	
	for key: StringName in placement_values:
		match key:
			ROTATION_KEY:
				data.rotation = deg_to_rad(placement_values.get(key))
			SCALE_KEY:
				data.scale = placement_values.get(key)
			_:
				data.values.set(key, placement_values.get(key))


func get_placement_tool(entry: ObjectRegistry.Entry) -> LDTool:
	return _pick(get_tools().filter(func(tool: LDTool) -> bool: return tool.shape_kinds.has(entry.get_shape_kind())))


func get_last_subtool(button: BaseButton) -> LDTool:
	return _last_subtool.get(button)


func _pick(fitting: Array[LDTool]) -> LDTool:
	for tool: LDTool in fitting:
		if tool.group_button and _last_subtool.get(tool.group_button) == tool:
			return tool
	fitting.sort_custom(func(a: LDTool, b: LDTool) -> bool: return a.preferred and not b.preferred)
	return fitting.front() if not fitting.is_empty() else null


func get_edit_tool(object: GameObject) -> LDTool:
	if object == null or object.shape == null:
		return null
	
	for tool: LDTool in get_tools():
		if tool.edit_kinds.has(object.shape.get_kind()):
			return tool
	
	return null


func enter_edit_tool(object: GameObject) -> void:
	var tool: LDWidgetTool = get_edit_tool(object) as LDWidgetTool
	if tool == null or tool == active_tool:
		return
	
	set_tool(tool)
	tool.continue_forwarding()


func _on_button_pressed(button: BaseButton) -> void:
	var tools: Array[LDTool] = get_tools().filter(func(tool: LDTool) -> bool: return tool.button == button or tool.group_button == button)
	var kind: ObjectShape.Kind = armed.get_shape_kind() if armed else ObjectShape.Kind.NONE
	var picked: LDTool = _pick(tools.filter(func(tool: LDTool) -> bool: return tool.shape_kinds.has(kind)))
	set_tool(picked if picked else tools.front())


func cycle_tool(direction: int) -> void:
	var available: Array[LDTool] = get_tools().filter(func(tool: LDTool) -> bool: return tool.button and tool.button.is_visible_in_tree() and not tool.button.disabled)
	if available.is_empty():
		return
	
	set_tool(available.get(posmod(available.find(active_tool) + direction, available.size())))


func cancel() -> void:
	active_tool._cancel()


func handle_input(event: InputEvent, world_position: Vector2) -> bool:
	return active_tool._tool_input(event, world_position)
