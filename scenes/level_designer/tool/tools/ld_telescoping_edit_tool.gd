class_name LDTelescopingEditTool
extends LDWidgetTool

@export var cap_style: LDHandleStyle

var _before_units: int = 0
var _before_transform: Transform2D


static func get_shape(object: GameObject) -> TelescopingShape:
	return object.shape as TelescopingShape if object else null


func _get_targets(objects: Array[GameObject]) -> Array[GameObject]:
	return objects if objects.size() == 1 and get_shape(objects.front()) else []


func _layout_handles() -> void:
	var object: GameObject = targets.front()
	var shape: TelescopingShape = get_shape(object)
	var axis: Vector2 = shape.get_axis_vector()
	var half: float = shape.get_length() * 0.5
	var resize_cursor: Control.CursorShape = (
			Control.CURSOR_HSIZE
			if shape.axis == TelescopingShape.Axis.HORIZONTAL
			else Control.CURSOR_VSIZE
	)
	for side: int in [-1, 1]:
		var handle: LDHandle = \
				place_handle(side, object.get_global_transform() * (axis * half * side), cap_style)
		handle.cursor = resize_cursor
		handle.angle = (
				(editor.world.get_canvas_transform() * object.get_global_transform()).get_rotation()
				+ (0.0 if shape.axis == TelescopingShape.Axis.HORIZONTAL else PI * 0.5)
		)


func _on_handle_pressed(_handle: LDHandle) -> void:
	_before_units = get_shape(targets.front()).units
	_before_transform = targets.front().transform


func _on_handle_dragged(handle: LDHandle, world_position: Vector2) -> void:
	var object: GameObject = targets.front()
	var shape: TelescopingShape = get_shape(object)
	var side: int = handle.key
	var axis: Vector2 = shape.get_axis_vector()
	var start_length: float = shape.get_length(_before_units)
	var local: Vector2 = \
			_before_transform.affine_inverse() * to_parent(object, world_position, false)
	var reach: float = local.dot(axis) * side + start_length * 0.5
	var units: int = clampi(
			roundi((reach - shape.get_caps_length()) / shape.get_segment_length()),
			shape.min_units,
			shape.max_units,
	)
	_resize(object, units, side)


func _on_handle_released(_handle: LDHandle) -> void:
	_commit("Resize Telescoping Object")


func _on_handle_cancelled(_handle: LDHandle) -> void:
	var object: GameObject = targets.front()
	get_shape(object).set_units(_before_units)
	object.transform = _before_transform
	object.invalidate_bounds()


func _on_handle_reset(handle: LDHandle) -> void:
	_on_handle_pressed(handle)
	_resize(targets.front(), get_shape(targets.front()).default_units, handle.key)
	_commit("Reset Telescoping Object")


func _resize(object: GameObject, units: int, side: int) -> void:
	var shape: TelescopingShape = get_shape(object)
	var shift: float = (shape.get_length(units) - shape.get_length(_before_units)) * 0.5 * side
	shape.set_units(units)
	object.position = (
			_before_transform.origin
			+ _before_transform.basis_xform(shape.get_axis_vector() * shift)
	)
	object.invalidate_bounds()


func _commit(action_name: String) -> void:
	var object: GameObject = targets.front()
	var shape: TelescopingShape = get_shape(object)
	if shape.units == _before_units:
		return
	
	editor.history_handler.create(action_name).do(
			_apply.bind(object, shape.units, object.transform)
	).undo(_apply.bind(object, _before_units, _before_transform)).commit()


func _apply(object: GameObject, units: int, object_transform: Transform2D) -> void:
	get_shape(object).set_units(units)
	object.transform = object_transform
	object.invalidate_bounds()
	editor.object_handler.notify_changed()
