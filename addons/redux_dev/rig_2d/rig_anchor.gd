@tool
class_name RigAnchor
extends Marker2D


signal captured(before: Dictionary[StringName, Variant])

enum KeyScope {
	FRAME,
	CLIP,
	ALL,
}

static var auto_key: bool = false
static var key_scope: KeyScope = KeyScope.FRAME

@export var rest_position: Vector2 = Vector2.ZERO
@export var rest_rotation_degrees: float = 0.0
@export var interpolate: bool = false
@export var keys: Dictionary[StringName, Array] = {}

var z: int = 0

var _applied: Transform2D = Transform2D.IDENTITY
var _posed: bool = false
var _animation: StringName = &""
var _frame: int = -1


func pose(animation: StringName, frame: int, offset: Vector2) -> void:
	var moved: bool = Engine.is_editor_hint() and _posed and transform != _applied
	var same: bool = animation == _animation and frame == _frame
	_animation = animation
	_frame = frame
	var dragging: bool = Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if moved and (animation.is_empty() or auto_key) and not dragging:
		_capture(animation, frame, offset)
	elif moved and same:
		return
	
	var key: RigKey = get_active_key(animation, frame)
	var position_at: Vector2 = key.position if key else rest_position
	var rotation_at: float = key.rotation_degrees if key else rest_rotation_degrees
	var next: RigKey = get_next_key(animation, frame) if interpolate and key else null
	if next:
		var weight: float = float(frame - key.frame) / float(next.frame - key.frame)
		position_at = position_at.lerp(next.position, weight)
		rotation_at = lerpf(rotation_at, next.rotation_degrees, weight)
	transform = Transform2D(deg_to_rad(rotation_at), position_at + offset)
	z = key.z_index if key else 0
	_applied = transform
	_posed = true


func duplicate_keys() -> Dictionary[StringName, Array]:
	var copy: Dictionary[StringName, Array] = {}
	for animation: StringName in keys:
		copy[animation] = keys[animation].duplicate()
	return copy


func get_active_key(animation: StringName, frame: int) -> RigKey:
	var active: RigKey = null
	for key: RigKey in keys.get(animation, []):
		if key.frame > frame:
			break
		active = key
	return active


func get_next_key(animation: StringName, frame: int) -> RigKey:
	for key: RigKey in keys.get(animation, []):
		if key.frame > frame:
			return key
	return null


func get_key(animation: StringName, frame: int) -> RigKey:
	for key: RigKey in keys.get(animation, []):
		if key.frame == frame:
			return key
	return null


func set_key(animation: StringName, key: RigKey) -> void:
	var list: Array = keys.get(animation, [])
	list = list.filter(func(other: RigKey) -> bool: return other.frame != key.frame)
	list.append(key)
	list.sort_custom(func(a: RigKey, b: RigKey) -> bool: return a.frame < b.frame)
	keys[animation] = list


func make_key(frame: int, offset: Vector2) -> RigKey:
	var key: RigKey = RigKey.new()
	key.frame = frame
	key.position = position - offset
	key.rotation_degrees = rotation_degrees
	key.z_index = z
	return key


func remove_key(animation: StringName, frame: int) -> void:
	var list: Array = keys.get(animation, [])
	list = list.filter(func(key: RigKey) -> bool: return key.frame != frame)
	if list.is_empty():
		keys.erase(animation)
	else:
		keys[animation] = list


func _capture(animation: StringName, frame: int, offset: Vector2) -> void:
	var before: Dictionary[StringName, Variant] = {
		&"keys": duplicate_keys(),
		&"rest_position": rest_position,
		&"rest_rotation_degrees": rest_rotation_degrees,
	}
	var shift: Vector2 = position - _applied.origin
	var turn: float = rad_to_deg(angle_difference(_applied.get_rotation(), rotation))
	if animation.is_empty():
		rest_position = position - offset
		rest_rotation_degrees = rotation_degrees
	elif key_scope == KeyScope.FRAME:
		set_key(animation, make_key(frame, offset))
	elif key_scope == KeyScope.CLIP:
		if get_active_key(animation, 0) == null:
			set_key(animation, _rest_key())
		_offset_keys(animation, shift, turn)
	else:
		rest_position += shift
		rest_rotation_degrees += turn
		for clip: StringName in keys:
			_offset_keys(clip, shift, turn)
	captured.emit(before)


func _offset_keys(animation: StringName, shift: Vector2, turn: float) -> void:
	var list: Array = []
	for key: RigKey in keys[animation]:
		var moved: RigKey = key.duplicate()
		moved.position += shift
		moved.rotation_degrees += turn
		list.append(moved)
	keys[animation] = list


func _rest_key() -> RigKey:
	var key: RigKey = RigKey.new()
	key.position = rest_position
	key.rotation_degrees = rest_rotation_degrees
	return key
