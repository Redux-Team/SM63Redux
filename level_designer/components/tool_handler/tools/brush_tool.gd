extends LDTool


var _preview_cursor: LDObject
var _stroke: Array[LDObject] = []
var _stroke_origin: Vector2
var _last_cell_x: int = 0
var _last_cell_y: Dictionary[int, float] = {}
var _column_objects: Dictionary[int, Array] = {}
var _is_painting: bool = false
var _cached_stamp_size: Vector2 = Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
## The placed player spawn, held for as long as it stays on the layer being painted. Placement
## rules ask for it once per stamped object, and resolving it rebuilds and scans the layer's whole
## object list, so a single drag across a large level was quadratic without this.
var _cached_player: LDObject = null


func get_tool_name() -> String:
	return "Brush"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	
	LD.get_editor_viewport().viewport_moved.connect(_on_viewport_moved)
	LD.get_object_handler().selected_object_changed.connect(_on_object_changed)
	
	viewport.touch_tap.connect(_on_touch_tap)
	viewport.touch_swipe_began.connect(_on_touch_swipe_began)
	viewport.touch_swipe_moved.connect(_on_touch_swipe_moved)
	viewport.touch_swipe_ended.connect(_on_touch_swipe_ended)
	
	if LD.get_object_handler().get_selected_object():
		_on_object_changed(LD.get_object_handler().get_selected_object())


## Lives on the Singleton, so it keeps firing at a detached editor unless it is dropped on the
## way out of the tree.
func _enter_tree() -> void:
	Singleton.get_input_handler().input_type_changed.connect(_on_input_type_changed)


func _exit_tree() -> void:
	Singleton.get_input_handler().input_type_changed.disconnect(_on_input_type_changed)


func _on_enable() -> void:
	super()
	_on_object_changed(LD.get_object_handler().get_selected_object())


func _on_disable() -> void:
	_destroy_cursor()
	_clear_stroke()
	super()


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if get_viewport().is_input_handled():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if event is InputEventMouseMotion:
		var pos: Vector2 = viewport.get_snapped_mouse()
		if _preview_cursor:
			_preview_cursor.position = pos
		if _is_painting and not viewport.is_panning():
			_stamp_line_to(pos)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if viewport.is_panning():
				return
			_is_painting = true
			_stroke_origin = viewport.get_snapped_mouse()
			_column_objects.clear()
			_last_cell_x = _pos_to_cell_x(_stroke_origin)
			_last_cell_y.clear()
			_stamp_at(_last_cell_x, _stroke_origin.y)
		else:
			if _is_painting:
				_commit_stroke()
			_is_painting = false


func _on_viewport_moved(_pos: Vector2, _zoom: Vector2) -> void:
	_on_viewport_input(InputEventMouseMotion.new())


func _on_object_changed(obj: GameObject) -> void:
	_destroy_cursor()
	_clear_stroke()
	
	var active: LDTool = get_tool_handler().get_selected_tool()
	if active and active != self and active.can_place(obj):
		return
	
	if obj and obj.get_placement_tool():
		get_tool_handler().select_tool(obj.get_placement_tool())
		return
	
	_cache_stamp_size(obj)
	if not Singleton.get_input_handler().is_using_touch():
		_spawn_cursor(obj)


func _cache_stamp_size(obj: GameObject) -> void:
	if not obj:
		_cached_stamp_size = Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE)
		return
	var temp: LDObject = obj.get_editor_instance()
	_cached_stamp_size = temp.get_stamp_size()
	temp.free()


func _destroy_cursor() -> void:
	if _preview_cursor:
		_preview_cursor.queue_free()
		_preview_cursor = null


func _spawn_cursor(obj: GameObject) -> void:
	if not obj:
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	_preview_cursor = obj.get_editor_instance()
	_preview_cursor.is_preview = true
	_preview_cursor.init_properties(obj)
	_preview_cursor.bind_to_active_layer()
	LD.get_area().add_object(_preview_cursor)


func _get_stamp_size() -> Vector2:
	if _preview_cursor:
		return _preview_cursor.get_stamp_size()
	return _cached_stamp_size


func _stamp_line_to(pos: Vector2) -> void:
	var target_cell_x: int = _pos_to_cell_x(pos)
	var stamp_size: Vector2 = _get_stamp_size()
	
	if target_cell_x == _last_cell_x:
		var last_y: float = _last_cell_y.get(target_cell_x, pos.y - INF)
		if absf(pos.y - last_y) >= stamp_size.y and not _column_has_overlap(target_cell_x, pos.y):
			_stamp_at(target_cell_x, pos.y)
		return
	
	for cell_x: int in _columns_between(_last_cell_x, target_cell_x):
		if not _column_has_overlap(cell_x, pos.y):
			_stamp_at(cell_x, pos.y)
	
	_last_cell_x = target_cell_x


## Drops one preview in a column and records the entry the overlap tests read back.
func _stamp_at(cell_x: int, y: float) -> void:
	_add_stroke_preview(Vector2(_cell_x_to_pos(cell_x), y))
	var column: Array = _column_objects.get(cell_x, [])
	column.append(y)
	_column_objects.set(cell_x, column)
	_last_cell_y.set(cell_x, y)


func _add_stroke_preview(pos: Vector2) -> void:
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if not obj:
		return
	
	var preview: LDObject = obj.get_editor_instance()
	preview.is_preview = true
	preview.source_object_id = obj.id
	LD.get_area().add_object(preview, Vector2i(pos))
	
	match obj.ld_placement_rules:
		GameObject.LDPlacementRules.BEHIND_ALL:
			preview.get_parent().move_child(preview, 0)
		GameObject.LDPlacementRules.FRONT_ALL:
			preview.move_to_front()
		_:
			var player: LDObject = _player_on(preview.get_parent())
			if player:
				var player_index: int = player.get_index()
				match obj.ld_placement_rules:
					GameObject.LDPlacementRules.BEHIND_PLAYER:
						preview.get_parent().move_child(preview, player_index)
					GameObject.LDPlacementRules.FRONT_PLAYER:
						preview.get_parent().move_child(preview, player_index + 1)
	
	preview.init_properties(obj)
	if obj.has_property(&"position"):
		preview.set_property(&"position", pos)
	_stroke.append(preview)


## The player spawn sitting under `parent`, cached between calls.
func _player_on(parent: Node) -> LDObject:
	if is_instance_valid(_cached_player) and _cached_player.get_parent() == parent:
		return _cached_player
	_cached_player = LD.get_area().find_object_by_id("player_mario")
	if _cached_player and _cached_player.get_parent() != parent:
		_cached_player = null
	return _cached_player


func _commit_stroke() -> void:
	if _stroke.is_empty():
		return
	
	for obj: LDObject in _stroke:
		obj._first_placement()
	
	var placed: Array[LDObject] = _stroke.duplicate()
	var parents: Array[Node] = []
	var indices: Array[int] = []
	for obj: LDObject in placed:
		parents.append(obj.get_parent())
		indices.append(obj.get_index())
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.push("Place Objects",
		func() -> void:
			for i: int in placed.size():
				var obj: LDObject = placed.get(i)
				var parent: Node = parents.get(i)
				if not is_instance_valid(obj) or obj.get_parent() or not is_instance_valid(parent):
					continue
				parent.add_child(obj)
				parent.move_child(obj, mini(indices.get(i), parent.get_child_count() - 1)),
		func() -> void:
			for obj: LDObject in placed:
				if is_instance_valid(obj) and obj.get_parent():
					obj.get_parent().remove_child(obj)
	)
	history.track_detached(placed)
	
	_stroke.clear()
	_column_objects.clear()
	_last_cell_y.clear()


func _clear_stroke() -> void:
	for obj: LDObject in _stroke:
		obj.queue_free()
	_stroke.clear()
	_column_objects.clear()
	_last_cell_y.clear()
	_is_painting = false


func _column_has_overlap(cell_x: int, y: float) -> bool:
	var column: Array = _column_objects.get(cell_x, [])
	if column.is_empty():
		return false
	var stamp_size: Vector2 = _get_stamp_size()
	for existing_y: float in column:
		if absf(y - existing_y) < stamp_size.y:
			return true
	return false


func _pos_to_cell_x(pos: Vector2) -> int:
	var stamp_size: Vector2 = _get_stamp_size()
	var relative_x: float = pos.x - _stroke_origin.x
	return roundi(relative_x / stamp_size.x)


func _cell_x_to_pos(cell_x: int) -> float:
	var stamp_size: Vector2 = _get_stamp_size()
	return _stroke_origin.x + cell_x * stamp_size.x


func _columns_between(from_x: int, to_x: int) -> Array[int]:
	var columns: Array[int] = []
	var step: int = 1 if to_x > from_x else -1
	var x: int = from_x
	while x != to_x + step:
		columns.append(x)
		x += step
	return columns


func _on_touch_tap(pos: Vector2) -> void:
	if not is_active():
		return
	var world_pos: Vector2 = viewport.screen_to_world(pos).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
	_stroke_origin = world_pos
	_column_objects.clear()
	_last_cell_x = _pos_to_cell_x(world_pos)
	_last_cell_y.clear()
	_stamp_at(_last_cell_x, world_pos.y)
	_commit_stroke()


func _on_touch_swipe_began(pos: Vector2) -> void:
	if not is_active():
		return
	var world_pos: Vector2 = viewport.screen_to_world(pos).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
	_is_painting = true
	_stroke_origin = world_pos
	_column_objects.clear()
	_last_cell_x = _pos_to_cell_x(world_pos)
	_last_cell_y.clear()
	_stamp_at(_last_cell_x, world_pos.y)


func _on_touch_swipe_moved(pos: Vector2) -> void:
	if not is_active() or not _is_painting:
		return
	var world_pos: Vector2 = viewport.screen_to_world(pos).snapped(Vector2(LDViewport.SNAPPING_SIZE, LDViewport.SNAPPING_SIZE))
	_stamp_line_to(world_pos)


func _on_touch_swipe_ended() -> void:
	if not is_active():
		return
	if _is_painting:
		_commit_stroke()
	_is_painting = false


func _on_input_type_changed() -> void:
	if not is_active():
		return
	_destroy_cursor()
	var obj: GameObject = LD.get_object_handler().get_selected_object()
	if not obj:
		return
	if Singleton.get_input_handler().is_using_touch():
		_cache_stamp_size(obj)
	else:
		_spawn_cursor(obj)
