class_name LDRotateTool
extends LDWidgetTool

const BASE_RADIUS: float = 48.0
const RING_SPACING: float = 28.0
const NODE_RING: StringName = &""

@export var knob_style: LDHandleStyle
@export var ring_color: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var active_color: Color = Color("6496ed")
@export var snap_degrees: float = 15.0

var _rings: Array[StringName] = []
var _members: Array[GameObject] = []
var _before_transforms: Array[Transform2D] = []
var _before_values: Array = []
var _start_angle: float = 0.0


static func get_ring_keys(object: GameObject) -> Array[StringName]:
	var keys: Array[StringName] = []
	if object.has_flag(GameObject.Flag.ROTATABLE):
		keys.append(NODE_RING)
	for property: ObjectProperty in object.properties:
		if property.gizmo == ObjectProperty.Gizmo.ROTATION:
			keys.append(property.key)
	
	return keys


func _get_targets(objects: Array[GameObject]) -> Array[GameObject]:
	return objects.filter(
			func(object: GameObject) -> bool:
				return not get_ring_keys(object).is_empty()
	)


func refresh() -> void:
	super()
	if is_dragging():
		return
	
	_rings.clear()
	for object: GameObject in targets:
		for key: StringName in get_ring_keys(object):
			if not _rings.has(key):
				_rings.append(key)
	_rings.sort_custom(
			func(a: StringName, b: StringName) -> bool:
				return a != NODE_RING and b == NODE_RING
	)


func _layout_handles() -> void:
	for i: int in _rings.size():
		var key: StringName = _rings[i]
		var handle: LDHandle = place_handle(
				key,
				_to_world(_center_screen() + Vector2.from_angle(_get_angle(key)) * _radius(i)),
				knob_style,
		)
		handle.cursor = Control.CURSOR_DRAG if is_pressed(key) else Control.CURSOR_POINTING_HAND


func _draw_guides(overlay: LDOverlay) -> void:
	var center: Vector2 = _center_screen()
	for i: int in _rings.size():
		var key: StringName = _rings[i]
		var color: Color = active_color if is_hovered(key) or is_pressed(key) else ring_color
		overlay.canvas.draw_arc(center, _radius(i), 0.0, TAU, 64, color, 1.0, true)
		overlay.canvas.draw_line(
				center,
				center + Vector2.from_angle(_get_angle(key)) * _radius(i),
				color,
				1.0,
				true,
		)
	overlay.canvas.draw_circle(center, 2.5, active_color)


func _on_handle_pressed(handle: LDHandle) -> void:
	var key: StringName = handle.key
	_members = targets.filter(func(each: GameObject) -> bool: return get_ring_keys(each).has(key))
	_before_transforms = LDObjectHandler.get_transforms(_members)
	_before_values = _members.map(func(object: GameObject) -> Variant: return object.get_value(key))
	_start_angle = (
			editor.viewport_handler.to_screen(editor.viewport_handler.get_world_mouse())
			- _center_screen()
	).angle()


func _on_handle_dragged(handle: LDHandle, world_position: Vector2) -> void:
	var delta: float = angle_difference(
			_start_angle,
			(editor.viewport_handler.to_screen(world_position) - _center_screen()).angle(),
	)
	if not Input.is_action_pressed(&"ld_snap_bypass"):
		delta = snappedf(delta, deg_to_rad(snap_degrees))
	
	_apply(
			handle.key,
			func(i: int) -> float:
				return delta + (
					_before_transforms[i].get_rotation()
					if handle.key == NODE_RING
					else deg_to_rad(_before_values[i])
				)
	)


func _on_handle_released(handle: LDHandle) -> void:
	_commit(handle.key, "Rotate Objects")


func _on_handle_cancelled(handle: LDHandle) -> void:
	_apply(
			handle.key,
			func(i: int) -> float:
				return (
					_before_transforms[i].get_rotation()
					if handle.key == NODE_RING
					else deg_to_rad(_before_values[i])
				)
	)


func _on_handle_reset(handle: LDHandle) -> void:
	_on_handle_pressed(handle)
	_apply(handle.key, func(_i: int) -> float: return 0.0)
	_commit(handle.key, "Reset Rotation")


func _apply(key: StringName, angle_of: Callable) -> void:
	for i: int in _members.size():
		var object: GameObject = _members[i]
		var angle: float = angle_of.call(i)
		if key == NODE_RING:
			object.rotation = angle
			object.invalidate_bounds()
		else:
			object.set_value(key, wrapf(rad_to_deg(angle), 0.0, 360.0))


func _commit(key: StringName, action_name: String) -> void:
	if key == NODE_RING:
		editor.object_handler.transform_objects(
				_members,
				_before_transforms,
				LDObjectHandler.get_transforms(_members),
				action_name,
		)
	else:
		editor.object_handler.commit_values(
				_members,
				key,
				_before_values,
				_members.map(func(object: GameObject) -> Variant: return (object.get_value(key))),
				action_name,
		)


func _get_angle(key: StringName) -> float:
	var owners: Array[GameObject] = \
			targets.filter(func(each: GameObject) -> bool: return get_ring_keys(each).has(key))
	if owners.is_empty():
		return 0.0
	
	var object: GameObject = owners.front()
	var screen_rotation: float = \
			(editor.world.get_canvas_transform() * object.get_global_transform()).get_rotation()
	if key == NODE_RING:
		return screen_rotation
	
	return screen_rotation + deg_to_rad(object.get_value(key))


func _center_screen() -> Vector2:
	var center: Vector2 = Vector2.ZERO
	for object: GameObject in targets:
		center += object.global_position
	
	return editor.viewport_handler.to_screen(center / maxf(targets.size(), 1.0))


func _radius(ring: int) -> float:
	return BASE_RADIUS + RING_SPACING * ring


func _to_world(screen: Vector2) -> Vector2:
	return editor.world.get_canvas_transform().affine_inverse() * screen
