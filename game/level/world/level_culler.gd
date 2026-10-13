class_name LevelCuller
extends Node

@export var margin: float = 320.0
@export var frames_between_updates: int = 4

var _objects: Array[Node2D] = []
var _frame: int = 0


func track(object: Node2D) -> void:
	var colliders: Array[CollisionObject2D] = _colliders_of(object)
	for collider: CollisionObject2D in colliders:
		if collider is StaticBody2D:
			return
	
	_objects.append(object)
	for collider: CollisionObject2D in colliders:
		collider.disable_mode = CollisionObject2D.DISABLE_MODE_KEEP_ACTIVE


func _physics_process(_delta: float) -> void:
	_frame += 1
	if _frame % frames_between_updates != 0:
		return
	
	var view: Rect2 = _visible_world_rect()
	var living: Array[Node2D] = []
	for object: Node2D in _objects:
		if not is_instance_valid(object):
			continue
		
		living.append(object)
		var awake: bool = view.has_point(object.get_global_transform_with_canvas().origin)
		if awake != (object.process_mode != Node.PROCESS_MODE_DISABLED):
			_set_awake(object, awake)
	
	if living.size() != _objects.size():
		_objects = living


func _visible_world_rect() -> Rect2:
	return get_viewport().get_visible_rect().grow(margin)


func _set_awake(object: Node2D, awake: bool) -> void:
	object.process_mode = Node.PROCESS_MODE_INHERIT if awake else Node.PROCESS_MODE_DISABLED
	for collider: CollisionObject2D in _colliders_of(object):
		var area: Area2D = collider as Area2D
		if area:
			area.monitoring = awake


func _colliders_of(object: Node2D) -> Array[CollisionObject2D]:
	var result: Array[CollisionObject2D] = []
	var stack: Array[Node] = [object]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		var collider: CollisionObject2D = node as CollisionObject2D
		if collider:
			result.append(collider)
		
		stack.append_array(node.get_children())
	
	return result
