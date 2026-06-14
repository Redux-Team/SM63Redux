class_name LDGroupHandler
extends LDComponent

const PREVIEW_SIZE: int = 128
const PREVIEW_PADDING: float = 8.0


signal group_added(group: LDGroup)
signal group_removed(group_id: String)
signal group_changed(group: LDGroup)
signal anchor_placed(group: LDGroup, unique_id: String)
signal anchor_removed(group: LDGroup, unique_id: String)
signal armed_group_changed(group: LDGroup)


var _groups: Dictionary[String, LDGroup] = {}
var _armed_group: LDGroup = null


func _on_ready() -> void:
	# Persist groups into the session as soon as they change, so they survive an
	# editor reload even if the user never explicitly saves the level.
	group_added.connect(_persist_session.unbind(1))
	group_removed.connect(_persist_session.unbind(1))
	group_changed.connect(_persist_session.unbind(1))
	anchor_placed.connect(_persist_session.unbind(2))
	anchor_removed.connect(_persist_session.unbind(2))


func _persist_session() -> void:
	LD.get_save_load_handler().save_session()


func get_group(id: String) -> LDGroup:
	return _groups.get(id, null)


func get_all_groups() -> Array[LDGroup]:
	var result: Array[LDGroup] = []
	for group: LDGroup in _groups.values():
		result.append(group)
	return result


func has_group(id: String) -> bool:
	return _groups.has(id)


## Arms a group for click-to-place via the Place tool. Pass null to disarm.
func arm_group(group: LDGroup) -> void:
	_armed_group = group
	armed_group_changed.emit(group)


func get_armed_group() -> LDGroup:
	return _armed_group


func create_group(id: String) -> LDGroup:
	if has_group(id):
		return get_group(id)

	var group: LDGroup = LDGroup.new()
	group.id = id
	_groups[id] = group

	group_added.emit(group)
	return group


func remove_group(id: String) -> void:
	if not has_group(id):
		return
	
	_dehydrate_group(id)
	_groups.erase(id)
	group_removed.emit(id)


func rename_group(old_id: String, new_id: String) -> bool:
	if not has_group(old_id) or has_group(new_id):
		return false
	
	var group: LDGroup = _groups[old_id]
	group.id = new_id
	_groups[new_id] = group
	_groups.erase(old_id)

	# Re-point placed linked instances ("old_id:unique" -> "new_id:unique").
	for obj: LDObject in LDLevel.get_active_area().get_all_objects():
		var linked: String = get_object_linked_group(obj)
		if linked.begins_with(old_id + ":"):
			obj.set_meta(&"linked_group", new_id + linked.substr(old_id.length()))

	group_changed.emit(group)
	return true


func add_objects_to_group(group_id: String, objects: Array[LDObject]) -> void:
	var group: LDGroup = get_group(group_id)
	if not group:
		return
	
	var save_load: LDSaveLoadHandler = LD.get_save_load_handler()
	var old_objects: Array[Dictionary] = group.objects.duplicate(true)
	var new_entries: Array[Dictionary] = []
	var anchor_pos: Vector2 = _get_capture_anchor(group, objects)

	for obj: LDObject in objects:
		var game_object: GameObject = save_load.find_game_object_for(obj)
		if not game_object or not game_object.ld_groupable:
			continue
		var data: Dictionary = save_load._serialize_object(obj)
		if data.is_empty():
			continue
		data["local_offset"] = Packer.vec2_to_array(obj.position - anchor_pos)
		data["layer_index"] = _get_object_layer_index(obj)
		new_entries.append(data)

	if new_entries.is_empty():
		return

	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Add to Group: " + group_id)
	history.add_do(func() -> void:
		for entry: Dictionary in new_entries:
			group.objects.append(entry)
		_rehydrate_group(group)
		group_changed.emit(group)
	)
	history.add_undo(func() -> void:
		group.objects = old_objects.duplicate(true)
		_rehydrate_group(group)
		group_changed.emit(group)
	)
	history.commit_action()

	for entry: Dictionary in new_entries:
		group.objects.append(entry)

	_rehydrate_group(group)

	# Generate the preview only after the captured entries are in place, otherwise
	# it renders the old (empty, on first capture) object list and yields a blank icon.
	_request_preview(group)

	group_changed.emit(group)


func remove_objects_from_group(group_id: String, objects: Array[LDObject]) -> void:
	var group: LDGroup = get_group(group_id)
	if not group:
		return
	
	var old_objects: Array[Dictionary] = group.objects.duplicate(true)
	var ids_to_remove: Array[String] = []
	for obj: LDObject in objects:
		ids_to_remove.append(obj.source_object_id)

	var new_objects: Array[Dictionary] = group.objects.filter(func(entry: Dictionary) -> bool:
		return not ids_to_remove.has(entry.get("object_id", ""))
	)

	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Remove from Group: " + group_id)
	history.add_do(func() -> void:
		group.objects = new_objects.duplicate(true)
		_rehydrate_group(group)
		group_changed.emit(group)
	)
	history.add_undo(func() -> void:
		group.objects = old_objects.duplicate(true)
		_rehydrate_group(group)
		group_changed.emit(group)
	)
	history.commit_action()

	group.objects = new_objects.duplicate(true)

	_rehydrate_group(group)

	group_changed.emit(group)


func place_linked(group_id: String, unique_id: String, position: Vector2, layer_index: int) -> bool:
	var group: LDGroup = get_group(group_id)
	if not group:
		return false

	if group.has_anchor(unique_id):
		return false

	var anchor: Dictionary = group.add_anchor(unique_id, position, layer_index)
	var spawned: Array[LDObject] = _spawn_group_objects(group, position, layer_index)

	var is_primary: bool = group.anchors[0].get("unique_id", "") == unique_id
	for obj: LDObject in spawned:
		_mark_linked_object(obj, group.get_full_address(unique_id), is_primary)
	
	var area: LDArea = LDLevel.get_active_area()
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Place Linked Group: " + group_id + ":" + unique_id)
	history.add_do(func() -> void:
		if not group.has_anchor(unique_id):
			group.anchors.append(anchor)
		for obj: LDObject in spawned:
			if is_instance_valid(obj) and not obj.get_parent():
				var obj_layer: int = obj.get_meta(&"spawn_layer", layer_index)
				area.add_object(obj, Vector2i(obj.position), obj_layer)
		anchor_placed.emit(group, unique_id)
	)
	history.add_undo(func() -> void:
		group.remove_anchor(unique_id)
		for obj: LDObject in spawned:
			if is_instance_valid(obj) and obj.get_parent():
				obj.get_parent().remove_child(obj)
		anchor_removed.emit(group, unique_id)
	)
	history.commit_action()
	
	anchor_placed.emit(group, unique_id)
	return true


func remove_anchor(group_id: String, unique_id: String) -> void:
	var group: LDGroup = get_group(group_id)
	if not group:
		return
	
	var address: String = group.get_full_address(unique_id)
	var to_remove: Array[LDObject] = _get_objects_at_anchor(address)
	
	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Remove Anchor: " + address)
	history.add_do(func() -> void:
		group.remove_anchor(unique_id)
		for obj: LDObject in to_remove:
			if is_instance_valid(obj) and obj.get_parent():
				obj.get_parent().remove_child(obj)
		anchor_removed.emit(group, unique_id)
	)
	history.add_undo(func() -> void:
		var area: LDArea = LDLevel.get_active_area()
		group.add_anchor(unique_id, Vector2.ZERO, 0)
		for obj: LDObject in to_remove:
			if is_instance_valid(obj) and not obj.get_parent():
				var obj_layer: int = obj.get_meta(&"spawn_layer", 0)
				area.add_object(obj, Vector2i(obj.position), obj_layer)
		anchor_placed.emit(group, unique_id)
	)
	history.commit_action()
	
	group.remove_anchor(unique_id)
	for obj: LDObject in to_remove:
		if is_instance_valid(obj) and obj.get_parent():
			obj.get_parent().remove_child(obj)
	
	anchor_removed.emit(group, unique_id)


func get_object_linked_group(obj: LDObject) -> String:
	return str(obj.get_meta(&"linked_group", ""))


## Tags a spawned linked-group object with its anchor address. Non-primary anchors
## become grayscale, read-only "ghost" copies that mirror the primary.
func _mark_linked_object(obj: LDObject, address: String, is_primary: bool) -> void:
	obj.set_meta(&"linked_group", address)
	if not is_primary:
		obj.set_meta(&"ghost_instance", true)
		obj.set_meta(&"linked_readonly", true)
		obj.set_shader_parameter(&"saturation", 0.0)


## True if obj is a read-only "ghost" copy of a non-primary linked anchor.
func is_linked_readonly(obj: LDObject) -> bool:
	return bool(obj.get_meta(&"linked_readonly", false))


## All placed objects belonging to the same linked-group anchor instance as obj
## (used to select/move/delete a linked placement as a single unit).
func get_linked_instance_objects(obj: LDObject) -> Array[LDObject]:
	var address: String = get_object_linked_group(obj)
	if address.is_empty():
		return []
	return _get_objects_at_anchor(address)


## Removes the entire linked anchor instance that obj belongs to (and its objects).
func remove_anchor_for_object(obj: LDObject) -> void:
	var address: String = get_object_linked_group(obj)
	var parts: PackedStringArray = address.split(":")
	if parts.size() < 2:
		return
	remove_anchor(parts[0], parts[1])


## World position of the anchor that obj's linked instance is placed at.
func get_anchor_position_for_object(obj: LDObject) -> Vector2:
	var parts: PackedStringArray = get_object_linked_group(obj).split(":")
	if parts.size() < 2:
		return Vector2.ZERO
	var group: LDGroup = get_group(parts[0])
	if not group:
		return Vector2.ZERO
	var anchor: Dictionary = group.get_anchor(parts[1])
	if anchor.is_empty():
		return Vector2.ZERO
	return Packer.array_to_vec2(anchor.get("position", [0.0, 0.0]))


## Updates the stored position of a linked anchor (so a moved instance persists/rehydrates
## in its new spot). Address is "group_id:unique_id".
func set_anchor_position_by_address(address: String, pos: Vector2) -> void:
	var parts: PackedStringArray = address.split(":")
	if parts.size() < 2:
		return
	var group: LDGroup = get_group(parts[0])
	if not group:
		return
	var anchor: Dictionary = group.get_anchor(parts[1])
	if not anchor.is_empty():
		anchor["position"] = [pos.x, pos.y]


func is_primary_anchor_object(obj: LDObject) -> bool:
	var address: String = get_object_linked_group(obj)
	if address.is_empty():
		return false
	var parts: PackedStringArray = address.split(":")
	if parts.size() < 2:
		return false
	var group: LDGroup = get_group(parts[0])
	if not group or group.anchors.is_empty():
		return false
	return group.anchors[0].get("unique_id", "") == parts[1]


func serialize_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for group: LDGroup in _groups.values():
		result.append(group.serialize())
	return result


func deserialize_all(data: Array) -> void:
	_groups.clear()
	for entry: Variant in data:
		if not entry is Dictionary:
			continue
		var group: LDGroup = LDGroup.deserialize(entry)
		if group.id.is_empty():
			continue
		_groups[group.id] = group
	
	for group: LDGroup in _groups.values():
		_request_preview(group)


func generate_preview(group: LDGroup) -> void:
	if group.objects.is_empty():
		group.preview_texture = null
		return
	
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(PREVIEW_SIZE, PREVIEW_SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	viewport.transparent_bg = true
	viewport.disable_3d = true
	add_child(viewport)
	
	var root: Node2D = Node2D.new()
	viewport.add_child(root)
	
	var db: GameDB = GameDB.get_db()
	var instances: Array[LDObject] = []
	var bounds_min: Vector2 = Vector2(INF, INF)
	var bounds_max: Vector2 = Vector2(-INF, -INF)
	
	for entry: Dictionary in group.objects:
		var object_id: String = entry.get("object_id", "")
		var game_object: GameObject = LD.get_save_load_handler().find_game_object_by_id(object_id, db)
		if not game_object or not game_object.get_editor_instance():
			continue
		var instance: LDObject = game_object.get_editor_instance()
		var offset: Vector2 = Packer.array_to_vec2(entry.get("local_offset", [0.0, 0.0]))
		root.add_child(instance)
		instance.init_properties(game_object)
		instance.place()
		instance.position = offset
		instances.append(instance)
		bounds_min = bounds_min.min(offset)
		bounds_max = bounds_max.max(offset)
	
	if instances.is_empty():
		viewport.queue_free()
		group.preview_texture = null
		return
	
	var content_size: Vector2 = (bounds_max - bounds_min).max(Vector2(1.0, 1.0))
	var available: float = float(PREVIEW_SIZE) - PREVIEW_PADDING * 2.0
	var scale_factor: float = minf(available / content_size.x, available / content_size.y)
	
	var center: Vector2 = (bounds_min + bounds_max) * 0.5
	root.scale = Vector2(scale_factor, scale_factor)
	root.position = Vector2(PREVIEW_SIZE, PREVIEW_SIZE) * 0.5 - center * scale_factor
	
	await RenderingServer.frame_post_draw
	
	var img: Image = viewport.get_texture().get_image()
	group.preview_texture = ImageTexture.create_from_image(img)
	
	viewport.queue_free()
	group_changed.emit(group)


func _request_preview(group: LDGroup) -> void:
	generate_preview(group)


func rehydrate_all() -> void:
	for group: LDGroup in _groups.values():
		_rehydrate_group(group)


func _rehydrate_group(group: LDGroup) -> void:
	_dehydrate_group(group.id)

	for anchor: Dictionary in group.anchors:
		var unique_id: String = anchor.get("unique_id", "")
		var anchor_pos: Vector2 = Packer.array_to_vec2(anchor.get("position", [0.0, 0.0]))
		var anchor_layer: int = anchor.get("layer_index", 0)
		var address: String = group.get_full_address(unique_id)
		var spawned: Array[LDObject] = _spawn_group_objects(group, anchor_pos, anchor_layer)

		var is_primary: bool = group.anchors[0].get("unique_id", "") == unique_id
		for obj: LDObject in spawned:
			_mark_linked_object(obj, address, is_primary)


func _dehydrate_group(group_id: String) -> void:
	for obj: LDObject in LDLevel.get_active_area().get_all_objects():
		if get_object_linked_group(obj).begins_with(group_id + ":"):
			if obj.get_parent():
				obj.get_parent().remove_child(obj)


## Spawns one preview (ghost) instance per object in the group, positioned relative
## to anchor_pos. The instances are flagged as previews and are NOT committed to
## history; the caller owns them and should free them. Reposition with position_preview().
func spawn_preview(group: LDGroup, anchor_pos: Vector2) -> Array[LDObject]:
	if not group:
		return []
	return _spawn_group_objects(group, anchor_pos, LDLevel.get_active_area()._active_index, true)


## Moves a set of preview instances (from spawn_preview) so the group is anchored at anchor_pos.
func position_preview(instances: Array[LDObject], anchor_pos: Vector2) -> void:
	for instance: LDObject in instances:
		if not is_instance_valid(instance):
			continue
		instance.position = anchor_pos + instance.get_meta(&"preview_offset", Vector2.ZERO)


func _spawn_group_objects(group: LDGroup, anchor_pos: Vector2, default_layer: int = 0, as_preview: bool = false) -> Array[LDObject]:
	var result: Array[LDObject] = []
	var db: GameDB = GameDB.get_db()
	var area: LDArea = LDLevel.get_active_area()
	var save_load: LDSaveLoadHandler = LD.get_save_load_handler()

	for entry: Dictionary in group.objects:
		var object_id: String = entry.get("object_id", "")
		var game_object: GameObject = save_load.find_game_object_by_id(object_id, db)
		if not game_object:
			continue

		var instance: LDObject = game_object.get_editor_instance()
		if not instance:
			continue
		instance.is_preview = as_preview
		var local_offset: Vector2 = Packer.array_to_vec2(entry.get("local_offset", [0.0, 0.0]))
		var obj_layer: int = entry.get("layer_index", default_layer)
		var world_pos: Vector2 = anchor_pos + local_offset

		area.add_object(instance, Vector2i(world_pos), obj_layer)
		instance.init_properties(game_object)
		
		var props: Dictionary = entry.get("properties", {})
		for key: String in props:
			# The captured "position" is the object's original absolute position; the
			# spawn position comes from anchor + local_offset, so don't restore it here.
			if key == "position":
				continue
			instance.set_property(StringName(key), Packer.deserialize_json_variant(props.get(key)))

		if instance is LDObjectPolygon and entry.has("polygon_points"):
			var poly_obj: LDObjectPolygon = instance as LDObjectPolygon
			var points: PackedVector2Array = PackedVector2Array()
			for p: Variant in entry.get("polygon_points", []):
				points.append(Packer.array_to_vec2(p))
			poly_obj.apply_points(points)
		
		if instance is LDObjectPolygon and entry.has("polygon_holes"):
			var poly_obj: LDObjectPolygon = instance as LDObjectPolygon
			for hole_data: Variant in entry.get("polygon_holes", []):
				if not hole_data is Array:
					continue
				var hole_points: PackedVector2Array = PackedVector2Array()
				for p: Variant in hole_data:
					hole_points.append(Packer.array_to_vec2(p))
				if hole_points.size() >= 3:
					poly_obj.add_hole(hole_points)
		
		instance.set_meta(&"spawn_layer", obj_layer)
		if as_preview:
			instance.set_meta(&"preview_offset", local_offset)
		else:
			instance.place()
			# place() re-applies the (default) position property; pin it to the spawn position.
			if instance.has_property("position"):
				instance.set_property(&"position", world_pos)
			instance.position = world_pos
		result.append(instance)

	return result


func _get_objects_at_anchor(address: String) -> Array[LDObject]:
	var result: Array[LDObject] = []
	for obj: LDObject in LDLevel.get_active_area().get_all_objects():
		if get_object_linked_group(obj) == address:
			result.append(obj)
	return result


## The reference point captured objects are stored relative to. For an empty group
## this is the centroid of the incoming selection (so the group is anchored on itself);
## for an existing group it stays consistent with the objects already captured.
func _get_capture_anchor(group: LDGroup, objects: Array[LDObject]) -> Vector2:
	if not group.objects.is_empty():
		return _get_group_anchor_position(group)
	if objects.is_empty():
		return Vector2.ZERO
	var sum: Vector2 = Vector2.ZERO
	for obj: LDObject in objects:
		sum += obj.position
	return sum / float(objects.size())


func _get_group_anchor_position(group: LDGroup) -> Vector2:
	if group.objects.is_empty():
		return Vector2.ZERO
	
	var sum: Vector2 = Vector2.ZERO
	for entry: Dictionary in group.objects:
		sum += Packer.array_to_vec2(entry.get("position", [0.0, 0.0]))
	
	return sum / float(group.objects.size())


func _get_object_layer_index(obj: LDObject) -> int:
	for layer: LDLayer in LDLevel.get_active_area().layers:
		if obj.get_parent() == layer.get_objects_root():
			return layer.index
	return LDLevel.get_active_area()._active_index
