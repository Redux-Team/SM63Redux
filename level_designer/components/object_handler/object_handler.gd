class_name LDObjectHandler
extends Node


signal selected_object_changed(new: GameObject)


var _selected_object: GameObject


func get_selected_object() -> GameObject:
	return _selected_object


func select_object(object: GameObject) -> void:
	_selected_object = object
	selected_object_changed.emit(object)


func find_object(id: String) -> LDObject:
	var objects: Array[LDObject] = LD.get_area().get_all_objects()
	
	for obj: LDObject in objects:
		if obj.source_object_id == id:
			return obj
	
	return null


func get_placed_selection() -> Array[LDObject]:
	return LD.get_editor_viewport().get_selected_objects()


func delete_placed_selection() -> void:
	var objects: Array[LDObject] = get_placed_selection()
	if objects.is_empty():
		return

	var stamp_handler: LDStampHandler = LD.get_stamp_handler()
	LD.get_editor_viewport().clear_selection()

	# Stamp instances: drop the whole placement through the handler (which removes the
	# instance and persists it), once per unique placement. The rest are loose objects.
	var removed_addresses: Dictionary = {}
	var loose: Array[LDObject] = []
	for obj: LDObject in objects:
		var address: String = stamp_handler.get_object_linked_stamp(obj)
		if address.is_empty():
			loose.append(obj)
		elif not removed_addresses.has(address):
			removed_addresses[address] = true
			stamp_handler.remove_instance_for_object(obj)

	var deletable: Array[LDObject] = []
	for obj: LDObject in loose:
		var game_obj: GameObject = GameDB.get_db().find_game_object(obj.source_object_id)
		if game_obj and game_obj.ld_flags & (1 << GameObject.LD_DELETABLE):
			deletable.append(obj)

	if deletable.is_empty():
		return

	var parents: Array[Node] = []
	for obj: LDObject in deletable:
		parents.append(obj.get_parent())

	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Delete Objects")
	history.add_do(func() -> void:
		for obj: LDObject in deletable:
			if is_instance_valid(obj) and obj.get_parent():
				obj.get_parent().remove_child(obj)
	)
	history.add_undo(func() -> void:
		for i: int in deletable.size():
			if is_instance_valid(deletable[i]) and is_instance_valid(parents[i]):
				parents[i].add_child(deletable[i])
	)
	history.commit_action()
	
	for obj: LDObject in deletable:
		if obj.get_parent():
			obj.get_parent().remove_child(obj)


## Snapshots the current selection into a stamp. Pass `id` to name it (or to replace an
## existing stamp of that id); empty `id` auto-names a new one. Returns the stamp (or
## null if the selection has nothing stampable).
func create_stamp_from_selection(id: String = "") -> LDStamp:
	var objects: Array[LDObject] = get_placed_selection()
	if objects.is_empty():
		return null
	return LD.get_stamp_handler().create_stamp_from_objects(objects, id)


func add_selection_to_tag(tag: String) -> void:
	var objects: Array[LDObject] = get_placed_selection()
	if objects.is_empty():
		return
	LD.get_tag_handler().tag_objects(tag, objects)


func remove_selection_from_tag(tag: String) -> void:
	var objects: Array[LDObject] = get_placed_selection()
	if objects.is_empty():
		return
	LD.get_tag_handler().untag_objects(tag, objects)


func get_selection_tags() -> Array[String]:
	return LD.get_tag_handler().get_selection_tags(get_placed_selection())


func get_shared_properties(objects: Array[LDObject]) -> Array[LDProperty]:
	if objects.is_empty():
		return []
	
	if objects.size() == 1:
		return objects[0]._properties
	
	var result: Array[LDProperty] = []
	for prop: LDProperty in objects[0]._properties:
		if prop.exclusive:
			continue
		var shared: bool = true
		for i: int in range(1, objects.size()):
			var found: bool = false
			for other_prop: LDProperty in objects[i]._properties:
				if other_prop.key == prop.key:
					found = true
					break
			if not found:
				shared = false
				break
		if shared:
			result.append(prop)
	
	return result


func has_editable_properties(objects: Array[LDObject]) -> bool:
	for prop: LDProperty in get_shared_properties(objects):
		if not prop.visible_in_editor:
			continue
		match prop.type:
			LDProperty.Type.BOOL, LDProperty.Type.INT, LDProperty.Type.FLOAT, LDProperty.Type.VECTOR2:
				return true
	return false


func get_property_value(objects: Array[LDObject], key: StringName) -> Variant:
	if objects.is_empty():
		return null
	
	var first: Variant = objects[0].get_property(key)
	for i: int in range(1, objects.size()):
		if objects[i].get_property(key) != first:
			return _get_property_default(objects[0], key)
	return first


func set_property_on_selection(key: StringName, value: Variant) -> void:
	var objects: Array[LDObject] = get_placed_selection()
	if objects.is_empty():
		return
	
	var old_values: Array[Variant] = []
	for obj: LDObject in objects:
		old_values.append(obj.get_property(key))
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Set Property: " + key)
	history.add_do(func() -> void:
		for obj: LDObject in objects:
			if is_instance_valid(obj):
				obj.set_property(key, value)
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]):
				objects[i].set_property(key, old_values[i])
	)
	history.commit_action()
	
	for obj: LDObject in objects:
		obj.set_property(key, value)


func _get_property_default(obj: LDObject, key: StringName) -> Variant:
	for prop: LDProperty in obj._properties:
		if prop.key == key:
			return prop.default_value
	return null
