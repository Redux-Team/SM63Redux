extends LDTool


@export var shortcut_handler: LDSelectionShortcutHandler

var _is_box_selecting: bool = false
## Set while a box drag wants its hover states recomputed. Motion events can arrive several times
## per frame and the pass touches every object, so it is run once a frame instead of once an event.
var _hover_update_queued: bool = false
var _is_shift_selecting: bool = false
var _box_select_origin: Vector2
var _box_select_rect: Rect2
var _overlay: LDSelectionOverlay


func get_tool_name() -> String:
	return "Select"


func _on_ready() -> void:
	get_tool_handler().add_tool(self)
	_overlay = viewport.get_selection_overlay() as LDSelectionOverlay
	LD.get_object_handler().selected_object_changed.connect(_on_selected_object_changed)
	viewport.touch_tap.connect(_on_touch_tap)
	viewport.touch_swipe_began.connect(_on_touch_swipe_began)
	viewport.touch_swipe_moved.connect(_on_touch_swipe_moved)
	viewport.touch_swipe_ended.connect(_on_touch_swipe_ended)


func _on_viewport_input(event: InputEvent) -> void:
	if not is_active():
		return
	if Singleton.get_input_handler().is_using_touch():
		return
	
	if shortcut_handler:
		shortcut_handler.handle_input(event)
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var mouse_pos: Vector2 = viewport.get_screen_mouse()
			var move: LDToolMove = get_move_tool()
			if move and move.try_begin_drag(mouse_pos, viewport.get_selected_objects()):
				get_tool_handler().select_tool("move")
				return
			
			var clicked: LDObject = _get_object_at(mouse_pos)
			if clicked:
				var game_object: GameObject = GameDB.get_object(clicked.source_object_id)
				if game_object and game_object.get_select_tool():
					viewport.set_selected_objects([clicked])
					get_tool_handler().select_tool(game_object.get_select_tool())
					return
			
			_is_box_selecting = true
			_is_shift_selecting = event.shift_pressed
			_box_select_origin = mouse_pos
			_box_select_rect = Rect2(_box_select_origin, Vector2.ZERO)
		else:
			_is_box_selecting = false
			_commit_box_select()
			_overlay.hide_box()
	
	if event is InputEventMouseMotion and _is_box_selecting:
		_box_select_rect = Rect2(_box_select_origin, viewport.get_screen_mouse() - _box_select_origin).abs()
		_overlay.show_box(_box_select_rect)
		_queue_hover_update()


func _on_disable() -> void:
	_overlay.hide_box()
	_is_box_selecting = false
	_hover_update_queued = false
	super()


func _on_selected_object_changed(_obj: GameObject) -> void:
	viewport.clear_selection()
	_overlay.hide_box()
	_is_box_selecting = false


## Asks for a hover pass on the next frame. The box itself still follows the cursor immediately;
## only the per-object state, which is what costs anything, waits for the frame.
func _queue_hover_update() -> void:
	_hover_update_queued = true
	set_process(true)


func _process(_delta: float) -> void:
	set_process(false)
	if not _hover_update_queued:
		return
	_hover_update_queued = false
	if _is_box_selecting:
		_update_hover_states()


func _update_hover_states() -> void:
	begin_hit_pass()
	# `obj in array` is a linear scan, so testing every object against the selection each frame was
	# quadratic in the size of the selection.
	var selected: Dictionary[LDObject, bool] = {}
	for obj: LDObject in viewport.get_selected_objects():
		selected.set(obj, true)
	
	for obj: LDObject in _get_selectable_objects():
		if not obj.ld_flags & (1 << GameObject.LD_SELECTABLE):
			continue
		if obj.is_preview or obj.disabled:
			continue
		if selected.has(obj):
			obj.set_selection_state(LDObject.SelectionState.SELECTED)
			continue
		if _object_intersects_box(obj):
			obj.set_selection_state(LDObject.SelectionState.HOVERED)
		else:
			obj.set_selection_state(LDObject.SelectionState.HIDDEN)


func _commit_box_select() -> void:
	if _box_select_rect.size.length() < 4.0:
		var clicked: LDObject = _get_object_at(_box_select_origin)
		if _is_shift_selecting:
			var combined: Array[LDObject] = viewport.get_selected_objects().duplicate()
			if clicked:
				if clicked not in combined:
					combined.append(clicked)
				else:
					combined.erase(clicked)
			viewport.set_selected_objects(_expand_linked_selection(combined))
		else:
			var single: Array[LDObject] = []
			if clicked:
				single.append(clicked)
			viewport.set_selected_objects(_expand_linked_selection(single))
		return
	
	var found: Array[LDObject] = []
	begin_hit_pass()
	for obj: LDObject in _get_selectable_objects():
		if obj.is_preview or obj.disabled:
			continue
		if _object_intersects_box(obj):
			found.append(obj)
	
	if _is_shift_selecting:
		var combined: Array[LDObject] = viewport.get_selected_objects().duplicate()
		combined.append_array(found)
		viewport.set_selected_objects(_expand_linked_selection(combined))
	else:
		viewport.set_selected_objects(_expand_linked_selection(found))


## Expands any read-only linked-stamp "ghost" object to all objects in its instance
## instance, so a linked placement is selected as a single unit.
func _expand_linked_selection(objects: Array[LDObject]) -> Array[LDObject]:
	var gh: LDStampHandler = LD.get_stamp_handler()
	var result: Array[LDObject] = []
	var seen: Dictionary[LDObject, bool] = {}
	for obj: LDObject in objects:
		if gh.is_linked_readonly(obj):
			for member: LDObject in gh.get_linked_instance_objects(obj):
				if not seen.has(member):
					seen.set(member, true)
					result.append(member)
		elif not seen.has(obj):
			seen.set(obj, true)
			result.append(obj)
	return result


func _point_near_polygon_edge(point: Vector2, screen_points: PackedVector2Array, threshold: float) -> bool:
	var count: int = screen_points.size()
	for i: int in count:
		var a: Vector2 = screen_points.get(i)
		var b: Vector2 = screen_points.get((i + 1) % count)
		if Geometry2D.get_closest_point_to_segment(point, a, b).distance_to(point) <= threshold:
			return true
	return false


func _polygon_edge_intersects_box(screen_points: PackedVector2Array, box: Rect2) -> bool:
	var count: int = screen_points.size()
	var box_end: Vector2 = box.end
	var corners: PackedVector2Array = [
		box.position, Vector2(box_end.x, box.position.y), box_end, Vector2(box.position.x, box_end.y),
	]
	for i: int in count:
		var a: Vector2 = screen_points.get(i)
		var b: Vector2 = screen_points.get((i + 1) % count)
		if box.has_point(a):
			return true
		for e: int in 4:
			if Geometry2D.segment_intersects_segment(a, b, corners.get(e), corners.get((e + 1) % 4)) != null:
				return true
	return false


## Screen-space outline of a polygon object, written into `_hit_points` rather than returned so
## a pass reuses one buffer instead of allocating per object.
func _fill_polygon_hit_points(obj: LDObject, local: PackedVector2Array) -> void:
	var xform: Transform2D = object_screen_xform(obj)
	_hit_points.resize(local.size())
	for i: int in local.size():
		_hit_points.set(i, xform * local.get(i))


func _object_intersects_box(obj: LDObject) -> bool:
	# Polygons first: they carry their own outline and their editor area holds a CollisionPolygon2D
	# rather than the rectangles the shape test below expects.
	var poly_obj: LDObjectPolygon = obj as LDObjectPolygon
	if poly_obj and poly_obj.editor_polygon:
		# The polygon tests walk every point it owns, so they keep a cheap reject in front.
		var broad_rect: Rect2 = object_screen_rect(obj)
		if broad_rect.size != Vector2.ZERO and not _box_select_rect.intersects(broad_rect):
			return false
		
		_fill_polygon_hit_points(obj, poly_obj.editor_polygon.polygon)
		
		if poly_obj.polygon_data and poly_obj.polygon_data.edge_selection:
			return _polygon_edge_intersects_box(_hit_points, _box_select_rect)
		
		for p: Vector2 in _hit_points:
			if _box_select_rect.has_point(p):
				return true
		var box_end: Vector2 = _box_select_rect.end
		var corners: PackedVector2Array = [
			_box_select_rect.position, Vector2(box_end.x, _box_select_rect.position.y),
			box_end, Vector2(_box_select_rect.position.x, box_end.y),
		]
		for corner: Vector2 in corners:
			if Geometry2D.is_point_in_polygon(corner, _hit_points):
				return true
		return _polygon_edge_intersects_box(_hit_points, _box_select_rect)
	
	# Rectangular shapes go straight to the exact test: it opens with the same axis-aligned reject a
	# separate broad phase would do, so running one first only transformed the object twice.
	var local_points: PackedVector2Array = obj.get_shape_points()
	if not local_points.is_empty():
		var xform: Transform2D = object_screen_xform(obj)
		# Placed objects are hardly ever rotated, and an unrotated rectangle stays axis aligned, so
		# the whole test collapses to one rect overlap against two transformed corners.
		if is_zero_approx(xform.x.y) and is_zero_approx(xform.y.x):
			for offset: int in range(0, local_points.size(), 4):
				var a: Vector2 = xform * local_points.get(offset)
				var b: Vector2 = xform * local_points.get(offset + 2)
				if _box_select_rect.intersects(Rect2(a, b - a).abs(), true):
					return true
			return false
		_hit_points.resize(local_points.size())
		for i: int in local_points.size():
			_hit_points.set(i, xform * local_points.get(i))
		for offset: int in range(0, _hit_points.size(), 4):
			if quad_intersects_rect(_hit_points, offset, _box_select_rect):
				return true
		return false
	
	return _box_select_rect.intersects(object_stamp_screen_rect(obj))


func _get_selectable_objects() -> Array[LDObject]:
	if LD.get_ui().get_viewport_handler().is_ghosting_enabled():
		return LD.get_area().get_all_objects_on_layer()
	return LD.get_area().get_all_objects()


func _get_object_at(mouse_pos: Vector2) -> LDObject:
	begin_hit_pass()
	var all: Array[LDObject] = _get_selectable_objects()
	for i: int in range(all.size() - 1, -1, -1):
		var obj: LDObject = all.get(i)
		if obj.is_preview or obj.disabled:
			continue
		# A point query rejects on the cached bounds far more often than it hits, so unlike the box
		# test it is worth paying for the broad phase before transforming anything.
		var broad_rect: Rect2 = object_screen_rect(obj)
		if broad_rect.size != Vector2.ZERO and not broad_rect.has_point(mouse_pos):
			continue
		var poly_obj: LDObjectPolygon = obj as LDObjectPolygon
		if poly_obj:
			_fill_polygon_hit_points(obj, poly_obj.get_ring())
			if poly_obj.polygon_data and poly_obj.polygon_data.edge_selection:
				if _point_near_polygon_edge(mouse_pos, _hit_points, 6.0):
					return obj
			elif Geometry2D.is_point_in_polygon(mouse_pos, _hit_points):
				return obj
			continue
		if obj.get_shape_points().is_empty():
			if object_stamp_screen_rect(obj).has_point(mouse_pos):
				return obj
			continue
		if object_shapes_have_point(obj, mouse_pos):
			return obj
	
	return null


func _on_touch_tap(pos: Vector2) -> void:
	if not is_active():
		return
	var obj: LDObject = _get_object_at(pos)
	if obj:
		viewport.set_selected_objects(_expand_linked_selection([obj]))
		if obj is LDObjectPath:
			get_tool_handler().select_tool("path_edit")
		elif obj is LDObjectPolygon:
			get_tool_handler().select_tool("polygon_edit")
	else:
		viewport.clear_selection()


func _on_touch_swipe_began(pos: Vector2) -> void:
	if not is_active():
		return
	_is_box_selecting = true
	_is_shift_selecting = false
	_box_select_origin = pos
	_box_select_rect = Rect2(pos, Vector2.ZERO)


func _on_touch_swipe_moved(pos: Vector2) -> void:
	if not is_active():
		return
	_box_select_rect = Rect2(_box_select_origin, pos - _box_select_origin).abs()
	_overlay.show_box(_box_select_rect)
	_queue_hover_update()


func _on_touch_swipe_ended() -> void:
	if not is_active():
		return
	_is_box_selecting = false
	_commit_box_select()
	_overlay.hide_box()
