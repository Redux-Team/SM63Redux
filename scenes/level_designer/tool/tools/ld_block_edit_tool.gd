class_name LDBlockEditTool
extends LDWidgetTool

const CORNERS: Array[Vector2] = [
	Vector2(-1, -1),
	Vector2(1, -1),
	Vector2(1, 1),
	Vector2(-1, 1),
]

@export var corner_style: LDHandleStyle

var _before_size: Vector2
var _before_transform: Transform2D


static func get_shape(object: GameObject) -> BlockShape:
	return object.shape as BlockShape if object else null


func _get_targets(objects: Array[GameObject]) -> Array[GameObject]:
	return objects if objects.size() == 1 and get_shape(objects.front()) else []


func _layout_handles() -> void:
	var object: GameObject = targets.front()
	var half: Vector2 = get_shape(object).get_local_bounds().size * 0.5
	for i: int in CORNERS.size():
		var handle: LDHandle = \
				place_handle(i, object.get_global_transform() * (CORNERS[i] * half), corner_style)
		handle.cursor = LDViewportHandler.resize_cursor(
				editor.viewport_handler.to_screen(handle.world)
				- editor.viewport_handler.to_screen(object.global_position)
		)


func _on_handle_pressed(_handle: LDHandle) -> void:
	_before_size = get_shape(targets.front()).size
	_before_transform = targets.front().transform


func _on_handle_dragged(handle: LDHandle, world_position: Vector2) -> void:
	var object: GameObject = targets.front()
	var shape: BlockShape = get_shape(object)
	var corner: Vector2 = CORNERS[handle.key]
	var basis: Transform2D = Transform2D(_before_transform.get_rotation(), Vector2.ZERO)
	var anchor: Vector2 = _before_transform.origin - basis.basis_xform(corner * _before_size * 0.5)
	var reach: Vector2 = basis.basis_xform_inv(to_parent(object, world_position) - anchor)
	shape.set_size(reach.abs().snapped(Vector2.ONE * editor.viewport_handler.snap_size))
	var direction: Vector2 = Vector2(
			signf(reach.x) if not is_zero_approx(reach.x) else corner.x,
			signf(reach.y) if not is_zero_approx(reach.y) else corner.y,
	)
	object.position = anchor + basis.basis_xform(direction * shape.size * 0.5)
	object.invalidate_bounds()


func _on_handle_released(_handle: LDHandle) -> void:
	var object: GameObject = targets.front()
	var shape: BlockShape = get_shape(object)
	if shape.size == _before_size and object.transform == _before_transform:
		return
	
	editor.history_handler.create("Resize Block").do(
			_apply.bind(object, shape.size, object.transform)
	).undo(_apply.bind(object, _before_size, _before_transform)).commit()


func _on_handle_cancelled(_handle: LDHandle) -> void:
	_apply(targets.front(), _before_size, _before_transform)


func _apply(object: GameObject, size: Vector2, object_transform: Transform2D) -> void:
	get_shape(object).set_size(size)
	object.transform = object_transform
	object.invalidate_bounds()
	editor.object_handler.notify_changed()
