class_name LDRotationWidget
extends LDToolWidget


const BASE_RING_RADIUS: float = 48.0
const RING_SPACING: float = 28.0
const HANDLE_RADIUS: float = 6.0
const RING_COLOR: Color = Color(1.0, 1.0, 1.0, 0.6)
const HANDLE_COLOR: Color = Color(1.0, 1.0, 1.0, 1.0)
const HANDLE_HOVER_COLOR: Color = Color(0.4, 0.8, 1.0, 1.0)
const DOUBLE_CLICK_THRESHOLD: float = 0.3


class RingState:
	var property_key: StringName = &""
	var rotation_owner: StringName = &""
	var radius: float = BASE_RING_RADIUS
	var is_dragging: bool = false
	var did_drag: bool = false
	var last_click_time: float = 0.0
	var drag_start_angle: float = 0.0
	var drag_start_rotations: Array[float] = []
	var is_handle_hovered: bool = false


var _rings: Array[RingState] = []


func _on_activate() -> void:
	_rebuild_rings()
	request_redraw()


func _on_deactivate() -> void:
	_rings.clear()
	request_redraw()


@warning_ignore("unused_parameter")
func _on_refresh(objects: Array[LDObject]) -> void:
	_rebuild_rings()
	request_redraw()


func _rebuild_rings() -> void:
	var objects: Array[LDObject] = _bound_objects
	var seen: Dictionary = {}
	var keys: Array[StringName] = []
	for obj: LDObject in objects:
		for prop: LDProperty in obj.get_properties():
			if prop.key.begins_with("rotation") and not seen.has(prop.key):
				seen[prop.key] = true
				keys.append(prop.key)
	
	_rings.clear()
	for i: int in keys.size():
		var key: StringName = keys.get(i)
		var ring: RingState = RingState.new()
		ring.property_key = key
		ring.radius = BASE_RING_RADIUS + RING_SPACING * i
		for obj: LDObject in objects:
			for prop: LDProperty in obj.get_properties():
				if prop.key == key:
					ring.rotation_owner = (prop as LDPropertyRotation).rotation_owner
					break
			break
		_rings.append(ring)


func _on_input(event: InputEvent) -> void:
	var objects: Array[LDObject] = _bound_objects
	var center: Vector2 = _get_center_screen(objects)
	
	if event is InputEventMouseMotion:
		var mouse_pos: Vector2 = get_screen_mouse_pos()
		for ring: RingState in _rings:
			var was_hovered: bool = ring.is_handle_hovered
			ring.is_handle_hovered = mouse_pos.distance_to(_get_handle_pos(center, _get_display_angle(objects, ring), ring)) <= HANDLE_RADIUS * 2.0
			if was_hovered != ring.is_handle_hovered:
				request_redraw()
			
			if ring.is_dragging:
				ring.did_drag = true
				var angle: float = (mouse_pos - center).angle()
				var delta_deg: float = rad_to_deg(angle - ring.drag_start_angle)
				if not (event as InputEventMouseMotion).alt_pressed:
					delta_deg = snappedf(delta_deg, 15.0)
				for i: int in objects.size():
					objects.get(i).set_property(ring.property_key, ring.drag_start_rotations.get(i) + delta_deg)
				request_redraw()
	
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			var mouse_pos: Vector2 = get_screen_mouse_pos()
			var hit_any: bool = false
			for ring: RingState in _rings:
				if mouse_pos.distance_to(_get_handle_pos(center, _get_display_angle(objects, ring), ring)) <= HANDLE_RADIUS * 2.0:
					ring.is_dragging = true
					ring.did_drag = false
					ring.drag_start_angle = (mouse_pos - center).angle()
					ring.drag_start_rotations.clear()
					for obj: LDObject in objects:
						ring.drag_start_rotations.append(obj.get_property(ring.property_key) if obj.get_property(ring.property_key) != null else 0.0)
					hit_any = true
					break
			if not hit_any:
				select_tool("select")
		else:
			for ring: RingState in _rings:
				if ring.is_dragging:
					if ring.did_drag:
						_commit_rotation(objects, ring)
					else:
						var now: float = Time.get_ticks_msec() / 1000.0
						if now - ring.last_click_time <= DOUBLE_CLICK_THRESHOLD:
							_reset_rotation(objects, ring)
						ring.last_click_time = now
					ring.is_dragging = false
					ring.did_drag = false


func draw_overlay(draw_node: CanvasItem) -> void:
	var objects: Array[LDObject] = _bound_objects
	if objects.is_empty():
		return
	
	var center: Vector2 = _get_center_screen(objects)
	for ring: RingState in _rings:
		var current_angle: float = _get_display_angle(objects, ring)
		var handle_pos: Vector2 = _get_handle_pos(center, current_angle, ring)
		var handle_color: Color = HANDLE_HOVER_COLOR if ring.is_handle_hovered or ring.is_dragging else HANDLE_COLOR
		
		draw_node.draw_arc(center, ring.radius, 0.0, TAU, 64, RING_COLOR, 1.0)
		draw_node.draw_circle(handle_pos, HANDLE_RADIUS, handle_color)
		draw_node.draw_line(center, handle_pos, RING_COLOR, 1.0)


func _reset_rotation(objects: Array[LDObject], ring: RingState) -> void:
	var old_rotations: Array[float] = []
	for obj: LDObject in objects:
		old_rotations.append(obj.get_property(ring.property_key) if obj.get_property(ring.property_key) != null else 0.0)
	
	var history: LDHistoryHandler = get_history()
	history.begin_action("Reset Rotation")
	history.add_do(func() -> void:
		for obj: LDObject in objects:
			if is_instance_valid(obj):
				obj.set_property(ring.property_key, 0.0)
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects.get(i)):
				objects.get(i).set_property(ring.property_key, old_rotations.get(i))
	)
	history.commit_action()
	
	for obj: LDObject in objects:
		obj.set_property(ring.property_key, 0.0)
	request_redraw()


func _commit_rotation(objects: Array[LDObject], ring: RingState) -> void:
	var old_rotations: Array[float] = ring.drag_start_rotations.duplicate()
	var new_rotations: Array[float] = []
	for obj: LDObject in objects:
		new_rotations.append(obj.get_property(ring.property_key) if obj.get_property(ring.property_key) != null else 0.0)
	
	var history: LDHistoryHandler = get_history()
	history.begin_action("Rotate Objects")
	history.add_do(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects.get(i)):
				objects.get(i).set_property(ring.property_key, new_rotations.get(i))
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects.get(i)):
				objects.get(i).set_property(ring.property_key, old_rotations.get(i))
	)
	history.commit_action()


func _get_center_screen(objects: Array[LDObject]) -> Vector2:
	var sum: Vector2 = Vector2.ZERO
	for obj: LDObject in objects:
		sum += world_to_screen(obj.global_position + obj.get_origin_offset())
	return sum / objects.size()


func _get_owner_angle(objects: Array[LDObject], owner_key: StringName) -> float:
	if objects.is_empty() or owner_key == &"":
		return 0.0
	var rotation_val: Variant = objects.get(0).get_property(owner_key)
	return rotation_val if rotation_val != null else 0.0


func _get_display_angle(objects: Array[LDObject], ring: RingState) -> float:
	if objects.is_empty():
		return 0.0
	var own_val: Variant = objects.get(0).get_property(ring.property_key)
	var own_deg: float = own_val if own_val != null else 0.0
	return deg_to_rad(own_deg + _get_owner_angle(objects, ring.rotation_owner))


func _get_handle_pos(center: Vector2, angle: float, ring: RingState) -> Vector2:
	return center + Vector2(cos(angle), sin(angle)) * ring.radius
