@abstract class_name LDPolygonBooleanTool
extends LDPolygonStrokeTool

const GHOST_ALPHA: float = 0.85

@export var preview_root: Node2D
@export var result_color: Color = Color(0.49, 0.85, 0.34, 0.95)

var _ghosts: Array[GameObject] = []
var _hidden: Array[GameObject] = []
var _plan_cache: Plan


class Plan:
	var outputs: Array[Dictionary] = []
	var removed: Array[GameObject] = []
	var affected: Array[GameObject] = []
	
	
	func output(source: GameObject, rings: Array, spawned: bool) -> void:
		outputs.append({"source": source, "rings": rings, "spawned": spawned})
		if not affected.has(source):
			affected.append(source)
	
	
	func remove(object: GameObject) -> void:
		removed.append(object)
		if not affected.has(object):
			affected.append(object)
	
	
	func is_empty() -> bool:
		return outputs.is_empty() and removed.is_empty()


@abstract func _get_action_name() -> String
@abstract func _plan(targets: Array[GameObject], stroke: PackedVector2Array) -> Plan


func _deactivate() -> void:
	super()
	_clear_ghosts()


func _finish(points: PackedVector2Array) -> void:
	_clear_ghosts()
	var targets: Array[GameObject] = get_targets()
	if targets.is_empty():
		return
	
	var plan: Plan = _plan(targets, points)
	if plan.is_empty():
		return
	
	var history: LDHistoryHandler.Action = editor.history_handler.create(_get_action_name())
	var selected: Array[GameObject] = targets.filter(func(target: GameObject) -> bool: return not plan.removed.has(target))
	for result: Dictionary in plan.outputs:
		var source: GameObject = result.get("source")
		if result.get("spawned"):
			selected.append(spawn_copy(history, source, result.get("rings")))
		else:
			set_shape(history, source, result.get("rings"))
			if not selected.has(source):
				selected.append(source)
	for object: GameObject in plan.removed:
		editor.object_handler.queue_removal(history, object)
	history.commit()
	editor.object_handler.selection.set_objects(selected)


func _stroke_changed() -> void:
	_clear_ghosts()
	var stroke: PackedVector2Array = get_preview_points()
	var layer: LevelLayer = editor.level_handler.active_layer
	if not is_active() or layer == null or stroke.size() < PolygonShape.MIN_POINTS or not is_simple(stroke):
		return
	
	var targets: Array[GameObject] = get_targets()
	if targets.is_empty():
		return
	
	_plan_cache = _plan(targets, stroke)
	preview_root.global_transform = layer.get_objects_root().get_global_transform()
	for object: GameObject in _plan_cache.affected:
		object.visible = false
		_hidden.append(object)
	for result: Dictionary in _plan_cache.outputs:
		var source: GameObject = result.get("source")
		var data: ObjectData = source.to_data()
		data.shape = {}
		var ghost: GameObject = ObjectRegistry.spawn(data, GameObject.Context.EDITOR)
		ghost.modulate.a = GHOST_ALPHA
		var rings: Array[PackedVector2Array] = []
		for ring: PackedVector2Array in result.get("rings"):
			rings.append(LDPolygonTool.localize(ring, data.position))
		(ghost.shape as PolygonShape).set_rings(rings, [])
		preview_root.add_child(ghost)
		_ghosts.append(ghost)


func _draw_overlay(overlay: LDOverlay) -> void:
	super(overlay)
	var layer: LevelLayer = editor.level_handler.active_layer
	if layer == null or _plan_cache == null or _ghosts.is_empty():
		return
	
	var to_world: Transform2D = layer.get_objects_root().get_global_transform()
	for result: Dictionary in _plan_cache.outputs:
		for ring: PackedVector2Array in result.get("rings"):
			overlay.draw_world_polyline(to_world * TerrainPolygon.get_closed_points(ring), result_color, 2.0)


func _clear_ghosts() -> void:
	for ghost: GameObject in _ghosts:
		ghost.free()
	_ghosts.clear()
	for object: GameObject in _hidden:
		if is_instance_valid(object):
			object.visible = true
	_hidden.clear()
	_plan_cache = null


func get_targets() -> Array[GameObject]:
	var layer: LevelLayer = editor.level_handler.active_layer
	return editor.object_handler.selection.get_objects().filter(func(object: GameObject) -> bool: return object.shape is PolygonShape and editor.level_handler.active_area.get_layer_of(object) == layer)


static func to_layer_rings(object: GameObject) -> Array:
	var rings: Array = []
	for ring: PackedVector2Array in (object.shape as PolygonShape).get_rings():
		var moved: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in ring:
			moved.append(point + object.position)
		rings.append(moved)
	
	return rings


func set_shape(history: LDHistoryHandler.Action, object: GameObject, shape: Array) -> void:
	var polygon: PolygonShape = object.shape as PolygonShape
	var rings: Array[PackedVector2Array] = []
	for ring: PackedVector2Array in shape:
		rings.append(LDPolygonTool.localize(ring, object.position))
	history.do(polygon.set_rings.bind(rings, [] as Array[Dictionary])).undo(polygon.set_rings.bind(polygon.get_rings(), polygon.get_toplines()))


func spawn_copy(history: LDHistoryHandler.Action, source: GameObject, shape: Array) -> GameObject:
	var data: ObjectData = source.to_data()
	data.uuid = StringName(Packer.generate_uuid())
	data.position = editor.viewport_handler.snap(TerrainPolygon.get_bounds(shape.front()).get_center())
	data.shape = {}
	var copy: GameObject = ObjectRegistry.spawn(data, GameObject.Context.EDITOR)
	var rings: Array[PackedVector2Array] = []
	for ring: PackedVector2Array in shape:
		rings.append(LDPolygonTool.localize(ring, data.position))
	(copy.shape as PolygonShape).set_rings(rings, [])
	editor.object_handler.queue_addition(history, copy, editor.level_handler.active_layer)
	return copy
