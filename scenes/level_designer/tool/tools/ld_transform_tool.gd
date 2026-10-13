@abstract class_name LDTransformTool
extends LDTool

@export var guide_color: Color = Color(0.39, 0.59, 0.93, 0.8)

var _objects: Array[GameObject] = []
var _before: Array[Transform2D] = []
var _before_global: Array[Transform2D] = []
var _pivot: Vector2
var _start: Vector2
var _dragging: bool = false


@abstract func _get_flag() -> GameObject.Flag
@abstract func _get_action_name() -> String
@abstract func _apply(world_position: Vector2) -> void


func _deactivate() -> void:
	if _dragging:
		_finish()


func _cancel() -> void:
	if not _dragging:
		return
	
	_dragging = false
	for i: int in _objects.size():
		_objects.get(i).transform = _before.get(i)


func _tool_input(event: InputEvent, world_position: Vector2) -> bool:
	var mouse_button: InputEventMouseButton = event as InputEventMouseButton
	if mouse_button and mouse_button.button_index == MOUSE_BUTTON_LEFT:
		if mouse_button.pressed:
			_begin(world_position)
		elif _dragging:
			_finish()
		return _dragging or not mouse_button.pressed
	
	if event is InputEventMouseMotion and _dragging:
		_apply(world_position)
		return true
	
	return false


func _begin(world_position: Vector2) -> void:
	var selection: LDSelection = editor.object_handler.selection
	var hit: GameObject = editor.viewport_handler.pick(world_position)
	if hit and not selection.has(hit):
		selection.set_objects([hit])
	
	var flag: GameObject.Flag = _get_flag()
	_objects = selection.get_objects().filter(func(object: GameObject) -> bool: return object.has_flag(flag))
	if _objects.is_empty():
		return
	
	_before = LDObjectHandler.get_transforms(_objects)
	_before_global.clear()
	for object: GameObject in _objects:
		_before_global.append(object.get_global_transform())
	
	_pivot = selection.get_global_bounds().get_center()
	_start = world_position
	_dragging = true


func _finish() -> void:
	_dragging = false
	editor.object_handler.transform_objects(_objects, _before, LDObjectHandler.get_transforms(_objects), _get_action_name())


func _draw_overlay(overlay: LDOverlay) -> void:
	if _dragging:
		overlay.draw_world_circle(_pivot, 3.0, guide_color)
		overlay.draw_world_line(_pivot, editor.viewport_handler.get_world_mouse(), guide_color)
