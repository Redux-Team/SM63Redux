class_name LDPlaceTool
extends LDTool


## Single-placement tool for groups. Like the Brush, it shows a ghost that follows
## the cursor, but each left-click drops exactly one instance of the armed group
## (no drag-painting). Stays armed until another tool is selected or right-click cancels.


var _armed_group: LDGroup
var _ghost: Array[LDObject] = []


func get_tool_name() -> String:
	return "Place"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	LD.get_group_handler().armed_group_changed.connect(_on_armed_group_changed)


func _on_enable() -> void:
	super()
	_armed_group = LD.get_group_handler().get_armed_group()
	_spawn_ghost()


func _on_disable() -> void:
	_clear_ghost()
	super()


func _on_armed_group_changed(group: LDGroup) -> void:
	_armed_group = group
	if is_active():
		_spawn_ghost()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active() or get_viewport().is_input_handled():
		return

	if event is InputEventMouseMotion:
		LD.get_group_handler().position_preview(_ghost, _get_snapped_mouse_pos())

	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			get_tool_handler().select_tool("select")
		elif event.button_index == MOUSE_BUTTON_LEFT and not viewport.is_panning():
			_place_at(_get_snapped_mouse_pos())


func _place_at(pos: Vector2) -> void:
	if not _armed_group:
		get_tool_handler().select_tool("select")
		return

	var gh: LDGroupHandler = LD.get_group_handler()
	gh.place_linked(_armed_group.id, _next_anchor_id(_armed_group), pos, LDLevel.get_active_area()._active_index)


func _next_anchor_id(group: LDGroup) -> String:
	var index: int = 0
	while group.has_anchor("anchor_" + str(index)):
		index += 1
	return "anchor_" + str(index)


func _spawn_ghost() -> void:
	_clear_ghost()
	if not _armed_group:
		return
	_ghost = LD.get_group_handler().spawn_preview(_armed_group, _get_snapped_mouse_pos())


func _clear_ghost() -> void:
	for obj: LDObject in _ghost:
		if is_instance_valid(obj):
			obj.queue_free()
	_ghost.clear()


func _get_snapped_mouse_pos() -> Vector2:
	return viewport.get_root().get_local_mouse_position().snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
