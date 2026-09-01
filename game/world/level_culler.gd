class_name LevelCuller
extends Node

## Suspends level objects that are outside the camera view so their scripts, physics and area
## monitoring cost nothing while they cannot be seen. They resume the moment they come back inside
## the margin. Callers decide what is eligible; see [member Entity.cull_when_offscreen].


## How far beyond the screen edge an entity stays awake, so nothing visibly pops in.
@export var margin: float = 320.0
## Entities are only re-checked every this many physics frames; they cannot cross the margin in less.
@export var frames_between_updates: int = 4


var _objects: Array[Node2D] = []
var _frame: int = 0


## Static world geometry is never suspended: it carries no per-frame cost worth reclaiming, and the
## view test uses the object's origin, which for a long terrain polygon can sit well off screen
## while the surface the player is standing on is not.
##
## For everything else, suspending a node would otherwise remove its collision from the simulation
## ([constant CollisionObject2D.DISABLE_MODE_REMOVE]), so bodies are kept active and only their
## scripts sleep.
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
		var awake: bool = view.has_point(object.global_position)
		if awake != (object.process_mode != Node.PROCESS_MODE_DISABLED):
			_set_awake(object, awake)
	
	if living.size() != _objects.size():
		_objects = living


func _visible_world_rect() -> Rect2:
	var canvas: Transform2D = get_viewport().get_canvas_transform()
	var zoom: Vector2 = canvas.get_scale()
	var size: Vector2 = get_viewport().get_visible_rect().size / zoom
	return Rect2(-canvas.origin / zoom, size).grow(margin)


## Suspending the whole subtree stops scripts, raycasts and particles without having to remember
## which of them were individually enabled. Areas stay in the simulation, so their monitoring is
## turned off separately to keep them out of the broadphase; they stay monitorable so the player
## can still be detected entering water and other triggers.
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
		
		for child: Node in node.get_children():
			stack.append(child)
	
	return result
