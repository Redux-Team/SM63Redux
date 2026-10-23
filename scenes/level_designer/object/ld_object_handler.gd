class_name LDObjectHandler
extends LDHandler

signal objects_changed

const BY_PLACEMENT: int = -2

@export var selection: LDSelection
@export var clipboard: LDClipboard
@export var browser: LDObjectBrowser
@export var inspector: LDInspector
@export var text_editor: LDTextEditor

var _change_queued: bool = false


static func get_transforms(objects: Array[GameObject]) -> Array[Transform2D]:
	var transforms: Array[Transform2D] = []
	for object: GameObject in objects:
		transforms.append(object.transform)
	
	return transforms


func notify_changed() -> void:
	if not _change_queued:
		_change_queued = true
		_flush_changed.call_deferred()


func spawn(object_id: StringName, local_position: Vector2) -> GameObject:
	var data: ObjectData = ObjectData.create(object_id)
	data.position = local_position
	editor.tool_handler.apply_placement_values(data)
	return ObjectRegistry.spawn(data, GameObject.Context.EDITOR)


func add_objects(
		objects: Array[GameObject],
		layer: LevelLayer,
		action_name: String = "Add Objects",
		select: bool = true,
) -> void:
	if objects.is_empty():
		return
	
	var action: LDHistoryHandler.Action = editor.history_handler.create(action_name)
	for object: GameObject in objects:
		if object.unique:
			for existing: GameObject in (editor.level_handler.active_area.get_all_objects()):
				if existing.id == object.id:
					queue_removal(action, existing)
		
		queue_addition(action, object, layer)
	
	action.commit()
	if select:
		selection.set_objects(objects)


func remove_objects(objects: Array[GameObject], action_name: String = "Delete Objects") -> void:
	var removable: Array[GameObject] = objects.filter(
			func(object: GameObject) -> bool:
				return object.has_flag(GameObject.Flag.DELETABLE)
	)
	if removable.is_empty():
		return
	
	removable.sort_custom(
			func(a: GameObject, b: GameObject) -> bool:
				return a.get_index() < b.get_index()
	)
	var action: LDHistoryHandler.Action = editor.history_handler.create(action_name)
	for object: GameObject in removable:
		queue_removal(action, object)
	
	action.commit()


func transform_objects(
		objects: Array[GameObject],
		before: Array[Transform2D],
		after: Array[Transform2D],
		action_name: String,
		merge: bool = false,
) -> void:
	if before == after:
		return
	
	editor.history_handler.create(
			action_name,
			UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE,
	).do(_set_transforms.bind(objects, after)).undo(_set_transforms.bind(objects, before)).commit()


func set_values(objects: Array[GameObject], key: StringName, value: Variant) -> void:
	var before: Array = []
	var after: Array = []
	for object: GameObject in objects:
		before.append(object.get_value(key))
		after.append(value)
	
	if before == after:
		return
	
	editor.history_handler.create("Set %s" % String(key).capitalize(), UndoRedo.MERGE_ENDS).do(
			_set_values.bind(objects, key, after)
	).undo(_set_values.bind(objects, key, before)).commit()


func commit_values(
		objects: Array[GameObject],
		key: StringName,
		before: Array,
		after: Array,
		action_name: String,
) -> void:
	if before == after:
		return
	
	editor.history_handler.create(action_name).do(_set_values.bind(objects, key, after)).undo(
			_set_values.bind(objects, key, before)
	).commit()


func reorder_objects(objects: Array[GameObject], to_front: bool) -> void:
	if objects.is_empty():
		return
	
	var sorted: Array[GameObject] = objects.duplicate()
	sorted.sort_custom(
			func(a: GameObject, b: GameObject) -> bool:
				return a.get_index() < b.get_index()
	)
	var before: Array[int] = []
	for object: GameObject in sorted:
		before.append(object.get_index())
	
	editor.history_handler.create("Bring to Front" if to_front else "Send to Back").do(
			_move_to_end.bind(sorted, to_front)
	).undo(_restore_indices.bind(sorted, before)).commit()


func queue_addition(action: LDHistoryHandler.Action, object: GameObject, layer: LevelLayer) -> void:
	action.do(_attach.bind(object, layer, BY_PLACEMENT)).undo(
			_detach.bind(object)
	).keep_on_do(object)


func queue_removal(action: LDHistoryHandler.Action, object: GameObject) -> void:
	var layer: LevelLayer = editor.level_handler.active_area.get_layer_of(object)
	action.do(_detach.bind(object)).undo(
			_attach.bind(object, layer, object.get_index())
	).keep_on_undo(object)


func _flush_changed() -> void:
	_change_queued = false
	objects_changed.emit()


func _attach(object: GameObject, layer: LevelLayer, at: int) -> void:
	layer.add_object(object, _placement_index(object, layer) if at == BY_PLACEMENT else at)
	notify_changed()


func _placement_index(object: GameObject, layer: LevelLayer) -> int:
	var player: GameObject = null
	for each: GameObject in layer.get_objects():
		if each.id == &"player_mario":
			player = each
	
	match object.placement:
		GameObject.Placement.BEHIND_ALL:
			return 0
		GameObject.Placement.BEHIND_PLAYER:
			return player.get_index() if player else -1
		GameObject.Placement.FRONT_PLAYER:
			return player.get_index() + 1 if player else -1
	
	return -1


func _detach(object: GameObject) -> void:
	object.get_parent().remove_child(object)
	selection.forget(object)
	notify_changed()


func _move_to_end(objects: Array[GameObject], to_front: bool) -> void:
	for i: int in objects.size():
		var object: GameObject = objects[i if to_front else objects.size() - 1 - i]
		object.get_parent().move_child(object, -1 if to_front else 0)
	notify_changed()


func _restore_indices(objects: Array[GameObject], indices: Array[int]) -> void:
	for i: int in objects.size():
		var object: GameObject = objects[i]
		object.get_parent().move_child(object, indices[i])
	notify_changed()


func _set_transforms(objects: Array[GameObject], transforms: Array[Transform2D]) -> void:
	for i: int in objects.size():
		var object: GameObject = objects[i]
		object.transform = transforms[i]
		object.invalidate_bounds()
	
	notify_changed()


func _set_values(objects: Array[GameObject], key: StringName, values: Array) -> void:
	for i: int in objects.size():
		(objects[i] as GameObject).set_value(key, values[i])
	
	notify_changed()
