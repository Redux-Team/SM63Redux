class_name LDObjectHandler
extends LDHandler

signal objects_changed

@export var selection: LDSelection
@export var clipboard: LDClipboard
@export var browser: LDObjectBrowser
@export var inspector: LDInspector


func spawn(object_id: StringName, local_position: Vector2) -> GameObject:
	var data: ObjectData = ObjectData.create(object_id)
	data.position = local_position
	return ObjectRegistry.spawn(data, GameObject.Context.EDITOR)


func add_objects(objects: Array[GameObject], layer: LevelLayer, action_name: String = "Add Objects") -> void:
	if objects.is_empty():
		return
	
	var action: LDHistoryHandler.Action = editor.history_handler.create(action_name)
	for object: GameObject in objects:
		if object.unique:
			for existing: GameObject in editor.level_handler.active_area.get_all_objects():
				if existing.id == object.id:
					_queue_removal(action, existing)
		
		action.do(_attach.bind(object, layer, -1)).undo(_detach.bind(object)).keep_on_do(object)
	
	action.commit()
	selection.set_objects(objects)


func remove_objects(objects: Array[GameObject], action_name: String = "Delete Objects") -> void:
	var removable: Array[GameObject] = objects.filter(func(object: GameObject) -> bool: return object.has_flag(GameObject.Flag.DELETABLE))
	if removable.is_empty():
		return
	
	removable.sort_custom(func(a: GameObject, b: GameObject) -> bool: return a.get_index() < b.get_index())
	var action: LDHistoryHandler.Action = editor.history_handler.create(action_name)
	for object: GameObject in removable:
		_queue_removal(action, object)
	
	action.commit()


func transform_objects(objects: Array[GameObject], before: Array[Transform2D], after: Array[Transform2D], action_name: String, merge: bool = false) -> void:
	if before == after:
		return
	
	editor.history_handler.create(action_name, UndoRedo.MERGE_ENDS if merge else UndoRedo.MERGE_DISABLE) \
		.do(_set_transforms.bind(objects, after)) \
		.undo(_set_transforms.bind(objects, before)) \
		.commit()


func set_values(objects: Array[GameObject], key: StringName, value: Variant) -> void:
	var before: Array = []
	var after: Array = []
	for object: GameObject in objects:
		before.append(object.get_value(key))
		after.append(value)
	
	if before == after:
		return
	
	editor.history_handler.create("Set %s" % String(key).capitalize(), UndoRedo.MERGE_ENDS) \
		.do(_set_values.bind(objects, key, after)) \
		.undo(_set_values.bind(objects, key, before)) \
		.commit()


func reorder_objects(objects: Array[GameObject], to_front: bool) -> void:
	if objects.is_empty():
		return
	
	var sorted: Array[GameObject] = objects.duplicate()
	sorted.sort_custom(func(a: GameObject, b: GameObject) -> bool: return a.get_index() < b.get_index())
	var before: Array[int] = []
	for object: GameObject in sorted:
		before.append(object.get_index())
	
	editor.history_handler.create("Bring to Front" if to_front else "Send to Back") \
		.do(_move_to_end.bind(sorted, to_front)) \
		.undo(_restore_indices.bind(sorted, before)) \
		.commit()


static func get_transforms(objects: Array[GameObject]) -> Array[Transform2D]:
	var transforms: Array[Transform2D] = []
	for object: GameObject in objects:
		transforms.append(object.transform)
	
	return transforms


func _queue_removal(action: LDHistoryHandler.Action, object: GameObject) -> void:
	var layer: LevelLayer = editor.level_handler.active_area.get_layer_of(object)
	action.do(_detach.bind(object)).undo(_attach.bind(object, layer, object.get_index())).keep_on_undo(object)


func _attach(object: GameObject, layer: LevelLayer, at: int) -> void:
	layer.add_object(object, at)
	objects_changed.emit()


func _detach(object: GameObject) -> void:
	object.get_parent().remove_child(object)
	objects_changed.emit()


func _move_to_end(objects: Array[GameObject], to_front: bool) -> void:
	for i: int in objects.size():
		var object: GameObject = objects.get(i if to_front else objects.size() - 1 - i)
		object.get_parent().move_child(object, -1 if to_front else 0)
	objects_changed.emit()


func _restore_indices(objects: Array[GameObject], indices: Array[int]) -> void:
	for i: int in objects.size():
		var object: GameObject = objects.get(i)
		object.get_parent().move_child(object, indices.get(i))
	objects_changed.emit()


func _set_transforms(objects: Array[GameObject], transforms: Array[Transform2D]) -> void:
	for i: int in objects.size():
		var object: GameObject = objects.get(i)
		object.transform = transforms.get(i)
		object.invalidate_bounds()
	
	objects_changed.emit()


func _set_values(objects: Array[GameObject], key: StringName, values: Array) -> void:
	for i: int in objects.size():
		(objects.get(i) as GameObject).set_value(key, values.get(i))
	
	objects_changed.emit()
