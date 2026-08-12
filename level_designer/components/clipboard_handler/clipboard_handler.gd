class_name LDClipboardHandler
extends LDComponent

signal clipboard_changed


const COPY_TO_SYSTEM_CLIPBOARD: bool = false


var _clipboard: Array[Dictionary] = []


func has_content() -> bool:
	return not _clipboard.is_empty()


func cut() -> void:
	copy()
	LD.get_object_handler().delete_placed_selection()


func copy() -> void:
	var objects: Array[LDObject] = LD.get_object_handler().get_placed_selection()
	if objects.is_empty():
		return
	
	_clipboard.clear()
	for obj: LDObject in objects:
		var game_object: GameObject = GameDB.get_db().find_game_object(obj.source_object_id)
		if not game_object or not game_object.ld_flags & (1 << GameObject.LD_COPYABLE):
			continue
		var data: Dictionary = _serialize_object(obj)
		if not data.is_empty():
			_clipboard.append(data)
	
	if COPY_TO_SYSTEM_CLIPBOARD and not _clipboard.is_empty():
		DisplayServer.clipboard_set(JSON.stringify(_clipboard, "\t"))
	clipboard_changed.emit()


func paste() -> void:
	_paste_internal(_clipboard, Vector2.ZERO)


func paste_offset(offset: Vector2 = Vector2.ZERO) -> void:
	_paste_internal(_clipboard, offset)


func paste_absolute(center: Vector2 = _get_clipboard_centroid()) -> void:
	_paste_internal(_clipboard, center - _get_clipboard_centroid())


func duplicate_objects() -> void:
	var objects: Array[LDObject] = LD.get_object_handler().get_placed_selection()
	if objects.is_empty():
		return
	
	var temp: Array[Dictionary] = []
	for obj: LDObject in objects:
		var game_object: GameObject = GameDB.get_db().find_game_object(obj.source_object_id)
		if not game_object or not game_object.ld_flags & (1 << GameObject.LD_COPYABLE):
			continue
		var data: Dictionary = _serialize_object(obj)
		if not data.is_empty():
			temp.append(data)
	
	_paste_internal(temp, Vector2(16, 16))


func _paste_internal(data: Array[Dictionary], offset: Vector2) -> void:
	if data.is_empty():
		return
	
	var db: GameDB = GameDB.get_db()
	var area: LDArea = LDLevel.get_active_area()
	var save_load: LDSaveLoadHandler = LD.get_save_load_handler()
	var spawned: Array[LDObject] = []
	
	for entry: Dictionary in data:
		var object_id: String = entry.get("object_id", "")
		var game_object: GameObject = save_load.find_game_object_by_id(object_id, db)
		if not game_object or not game_object.ld_flags & (1 << GameObject.LD_COPYABLE):
			continue
		var obj: LDObject = _deserialize_object(entry, db, area)
		if not obj:
			continue
		obj.position += offset
		spawned.append(obj)
	
	if spawned.is_empty():
		return
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Paste Objects")
	history.add_do(func() -> void:
		for obj: LDObject in spawned:
			if is_instance_valid(obj) and not obj.get_parent():
				area.add_object(obj, Vector2i(obj.position), area._active_index)
	)
	history.add_undo(func() -> void:
		for obj: LDObject in spawned:
			if is_instance_valid(obj) and obj.get_parent():
				obj.get_parent().remove_child(obj)
	)
	history.commit_action()
	
	LD.get_editor_viewport().set_selected_objects(spawned)


func _get_clipboard_centroid() -> Vector2:
	if _clipboard.is_empty():
		return Vector2.ZERO
	
	var sum: Vector2 = Vector2.ZERO
	for data: Dictionary in _clipboard:
		sum += Packer.array_to_vec2(data.get("position", [0.0, 0.0]))
	
	return sum / float(_clipboard.size())


func _serialize_object(obj: LDObject) -> Dictionary:
	return LD.get_save_load_handler()._serialize_object(obj)


func _deserialize_object(data: Dictionary, db: GameDB, area: LDArea, offset: Vector2 = Vector2.ZERO) -> LDObject:
	var object_id: String = data.get("object_id", "")
	if object_id.is_empty():
		return null
	
	var save_load: LDSaveLoadHandler = LD.get_save_load_handler()
	var game_object: GameObject = save_load.find_game_object_by_id(object_id, db)
	if not game_object:
		return null
	
	var instance: LDObject = game_object.get_editor_instance()
	var pos: Vector2 = Packer.array_to_vec2(data.get("position", [0.0, 0.0])) + offset
	
	area.add_object(instance, Vector2i(pos), area._active_index)
	instance.init_properties(game_object)
	
	var props: Dictionary = data.get("properties", {})
	for key: String in props:
		instance.set_property(StringName(key), Packer.deserialize_json_variant(props.get(key)))
	
	save_load.apply_polygon_data(instance, data)
	
	instance.place()
	return instance
