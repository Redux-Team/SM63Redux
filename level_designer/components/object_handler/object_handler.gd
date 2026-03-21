class_name LDObjectHandler
extends Node


signal selected_object_changed(new: GameObject)


var _selected_object: GameObject


func get_selected_object() -> GameObject:
	return _selected_object


func select_object(object: GameObject) -> void:
	_selected_object = object
	selected_object_changed.emit(object)


func get_placed_selection() -> Array[LDObject]:
	return LD.get_editor_viewport().get_selected_objects()


func delete_placed_selection() -> void:
	var objects: Array[LDObject] = get_placed_selection()
	if objects.is_empty():
		return
	
	LD.get_editor_viewport().clear_selection()
	
	var parents: Array[Node] = []
	for obj: LDObject in objects:
		parents.append(obj.get_parent())
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Delete Objects")
	history.add_do(func() -> void:
		for obj: LDObject in objects:
			if is_instance_valid(obj) and obj.get_parent():
				obj.get_parent().remove_child(obj)
	)
	history.add_undo(func() -> void:
		for i: int in objects.size():
			if is_instance_valid(objects[i]) and is_instance_valid(parents[i]):
				parents[i].add_child(objects[i])
	)
	history.commit_action()
	
	for obj: LDObject in objects:
		if obj.get_parent():
			obj.get_parent().remove_child(obj)


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
