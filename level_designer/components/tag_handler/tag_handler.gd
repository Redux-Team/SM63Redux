class_name LDTagHandler
extends LDComponent

## Owns the level's tags: pure named labels applied to objects via a `tags` meta
## (Array[String]). Scenarios target tags to enable/disable the objects carrying them.
## Unlike stamps, tags never spawn or capture objects - they only label existing ones.


signal tag_added(tag: String)
signal tag_removed(tag: String)
signal tag_changed(tag: String)


var _tags: Dictionary[String, bool] = {}


func _on_ready() -> void:
	# Persist tags into the session as soon as they change, so they survive an
	# editor reload even if the user never explicitly saves the level.
	tag_added.connect(_persist_session.unbind(1))
	tag_removed.connect(_persist_session.unbind(1))
	tag_changed.connect(_persist_session.unbind(1))


func _persist_session() -> void:
	LD.get_save_load_handler().save_session()


func has_tag(tag: String) -> bool:
	return _tags.has(tag)


func get_all_tags() -> Array[String]:
	var result: Array[String] = _tags.keys()
	result.sort()
	return result


func create_tag(tag: String) -> bool:
	if tag.is_empty() or _tags.has(tag):
		return false
	_tags[tag] = true
	tag_added.emit(tag)
	return true


func remove_tag(tag: String) -> void:
	if not _tags.has(tag):
		return
	# Strip the tag off every object that carries it.
	for obj: LDObject in _get_all_objects():
		var tags: Array[String] = get_object_tags(obj)
		if tags.has(tag):
			tags.erase(tag)
			obj.set_meta(&"tags", tags)
	_tags.erase(tag)
	tag_removed.emit(tag)


func rename_tag(old_tag: String, new_tag: String) -> bool:
	if not _tags.has(old_tag) or _tags.has(new_tag) or new_tag.is_empty():
		return false
	_tags.erase(old_tag)
	_tags[new_tag] = true
	for obj: LDObject in _get_all_objects():
		var tags: Array[String] = get_object_tags(obj)
		var idx: int = tags.find(old_tag)
		if idx >= 0:
			tags[idx] = new_tag
			obj.set_meta(&"tags", tags)
	tag_changed.emit(new_tag)
	return true


func get_object_tags(obj: LDObject) -> Array[String]:
	var raw: Variant = obj.get_meta(&"tags", [])
	var result: Array[String] = []
	for entry: Variant in raw:
		result.append(str(entry))
	return result


func tag_objects(tag: String, objects: Array[LDObject]) -> void:
	if tag.is_empty():
		return
	if not _tags.has(tag):
		create_tag(tag)
	for obj: LDObject in objects:
		var tags: Array[String] = get_object_tags(obj)
		if not tags.has(tag):
			tags.append(tag)
			obj.set_meta(&"tags", tags)
	tag_changed.emit(tag)


func untag_objects(tag: String, objects: Array[LDObject]) -> void:
	for obj: LDObject in objects:
		var tags: Array[String] = get_object_tags(obj)
		if tags.has(tag):
			tags.erase(tag)
			obj.set_meta(&"tags", tags)
	tag_changed.emit(tag)


func get_objects_with_tag(tag: String) -> Array[LDObject]:
	var result: Array[LDObject] = []
	for obj: LDObject in _get_all_objects():
		if get_object_tags(obj).has(tag):
			result.append(obj)
	return result


## Tags shared by every object in the current selection (intersection).
func get_selection_tags(objects: Array[LDObject]) -> Array[String]:
	if objects.is_empty():
		return []
	var result: Array[String] = get_object_tags(objects[0])
	for i: int in range(1, objects.size()):
		var obj_tags: Array[String] = get_object_tags(objects[i])
		result = result.filter(func(t: String) -> bool:
			return obj_tags.has(t)
		)
	return result


func serialize_all() -> Array[String]:
	return get_all_tags()


func deserialize_all(data: Array) -> void:
	_tags.clear()
	for entry: Variant in data:
		var tag: String = str(entry)
		if not tag.is_empty():
			_tags[tag] = true


func _get_all_objects() -> Array[LDObject]:
	if not is_instance_valid(LD.get_level()):
		return []
	var area: LDArea = LDLevel.get_active_area()
	if not area:
		return []
	return area.get_all_objects()
