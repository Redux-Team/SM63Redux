class_name LDRotationWidget
extends LDToolWidget


const BASE_RING_RADIUS: float = 48.0
const RING_SPACING: float = 28.0


class RingState:
	var property_key: StringName = &""
	var rotation_owner: StringName = &""
	var radius: float = BASE_RING_RADIUS
	var is_dragging: bool = false
	var did_drag: bool = false
	var drag_start_angle: float = 0.0
	var drag_start_rotations: Array[float] = []
	var is_handle_hovered: bool = false


@export var knobs: LDToolHandleSet


var _rings: Array[RingState] = []


func _on_activate() -> void:
	_attach_to_overlay()
	_rebuild_rings()
	request_redraw()


func _on_deactivate() -> void:
	_detach_from_overlay()
	_rings.clear()
	request_redraw()


@warning_ignore("unused_parameter")
func _on_refresh(objects: Array[LDObject]) -> void:
	_rebuild_rings()
	request_redraw()


func _rebuild_rings() -> void:
	var owners: Dictionary = {}
	var keys: Array[StringName] = []
	for obj: LDObject in _bound_objects:
		for prop: LDProperty in obj.get_properties():
			if prop.key.begins_with("rotation") and not owners.has(prop.key):
				owners.set(prop.key, prop.relative_to)
				keys.append(prop.key)
	
	_rings.clear()
	for i: int in keys.size():
		var key: StringName = keys.get(i)
		var ring: RingState = RingState.new()
		ring.property_key = key
		ring.rotation_owner = owners.get(key, &"")
		ring.radius = BASE_RING_RADIUS + RING_SPACING * i
		_rings.append(ring)


func _on_input(event: InputEvent) -> void:
	var objects: Array[LDObject] = _bound_objects
	var center: Vector2 = _get_center_screen(objects)
	_sync_knobs()
	
	if event is InputEventMouseMotion:
		var hovered: int = knobs.find_at(get_screen_mouse_pos())
		for i: int in _rings.size():
			var ring: RingState = _rings.get(i)
			if ring.is_handle_hovered != (i == hovered):
				ring.is_handle_hovered = i == hovered
				request_redraw()
			
			if ring.is_dragging:
				ring.did_drag = true
				var angle: float = (get_screen_mouse_pos() - center).angle()
				var delta_deg: float = rad_to_deg(angle - ring.drag_start_angle)
				if not (event as InputEventMouseMotion).alt_pressed:
					delta_deg = snappedf(delta_deg, 15.0)
				for j: int in objects.size():
					var obj: LDObject = objects.get(j)
					if obj.has_property(ring.property_key):
						obj.set_property(ring.property_key, ring.drag_start_rotations.get(j) + delta_deg)
				request_redraw()
	
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		var mb: InputEventMouseButton = event as InputEventMouseButton
		if mb.pressed:
			var hit: int = knobs.find_at(get_screen_mouse_pos())
			if hit < 0:
				select_tool("select")
			else:
				var ring: RingState = _rings.get(hit)
				ring.is_dragging = true
				ring.did_drag = false
				ring.drag_start_angle = (get_screen_mouse_pos() - center).angle()
				ring.drag_start_rotations.clear()
				for obj: LDObject in objects:
					ring.drag_start_rotations.append(obj.get_property(ring.property_key) if obj.get_property(ring.property_key) != null else 0.0)
		else:
			for i: int in _rings.size():
				var ring: RingState = _rings.get(i)
				if ring.is_dragging:
					if ring.did_drag:
						_commit_rotation(objects, ring)
					elif is_double_click(i):
						_reset_rotation(objects, ring)
					ring.is_dragging = false
					ring.did_drag = false


func draw_overlay(draw_node: CanvasItem) -> void:
	var objects: Array[LDObject] = _bound_objects
	if objects.is_empty():
		return
	
	var center: Vector2 = _get_center_screen(objects)
	var ring_color: Color = LDPalette.gizmo_edge()
	_sync_knobs()
	for ring: RingState in _rings:
		draw_node.draw_arc(center, ring.radius, 0.0, TAU, 64, ring_color, 1.0)
		draw_node.draw_line(center, _get_handle_pos(center, _get_display_angle(objects, ring), ring), ring_color, 1.0)


func _sync_knobs() -> void:
	var objects: Array[LDObject] = _bound_objects
	if objects.is_empty():
		knobs.clear()
		return
	
	var center: Vector2 = _get_center_screen(objects)
	var zoom: float = get_camera_zoom()
	var hovered: int = -1
	var pressed: int = -1
	knobs.resize_to(_rings.size())
	for i: int in _rings.size():
		var ring: RingState = _rings.get(i)
		knobs.place(i, _get_handle_pos(center, _get_display_angle(objects, ring), ring), zoom)
		knobs.set_shade(i, LDPalette.accent() if ring.is_handle_hovered or ring.is_dragging else LDPalette.vertex_fill())
		if ring.is_handle_hovered:
			hovered = i
		if ring.is_dragging:
			pressed = i
	knobs.set_active(hovered, pressed)


func _reset_rotation(objects: Array[LDObject], ring: RingState) -> void:
	var old_rotations: Array[float] = []
	for obj: LDObject in objects:
		old_rotations.append(obj.get_property(ring.property_key) if obj.get_property(ring.property_key) != null else 0.0)
	
	get_history().push("Reset Rotation",
		func() -> void:
			for obj: LDObject in objects:
				if is_instance_valid(obj) and obj.has_property(ring.property_key):
					obj.set_property(ring.property_key, 0.0),
		func() -> void:
			for i: int in objects.size():
				var obj: LDObject = objects.get(i)
				if is_instance_valid(obj) and obj.has_property(ring.property_key):
					obj.set_property(ring.property_key, old_rotations.get(i))
	)
	request_redraw()


func _commit_rotation(objects: Array[LDObject], ring: RingState) -> void:
	var old_rotations: Array[float] = ring.drag_start_rotations.duplicate()
	var new_rotations: Array[float] = []
	for obj: LDObject in objects:
		new_rotations.append(obj.get_property(ring.property_key) if obj.get_property(ring.property_key) != null else 0.0)
	
	get_history().push("Rotate Objects",
		func() -> void:
			for i: int in objects.size():
				var obj: LDObject = objects.get(i)
				if is_instance_valid(obj) and obj.has_property(ring.property_key):
					obj.set_property(ring.property_key, new_rotations.get(i)),
		func() -> void:
			for i: int in objects.size():
				var obj: LDObject = objects.get(i)
				if is_instance_valid(obj) and obj.has_property(ring.property_key):
					obj.set_property(ring.property_key, old_rotations.get(i))
	)


func _get_center_screen(objects: Array[LDObject]) -> Vector2:
	if objects.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for obj: LDObject in objects:
		sum += world_to_screen(obj.position + obj.get_origin_offset(), obj)
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
