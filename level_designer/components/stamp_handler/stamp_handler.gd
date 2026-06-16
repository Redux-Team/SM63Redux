class_name LDStampHandler
extends LDComponent

const PREVIEW_SIZE: int = 128
const PREVIEW_PADDING: float = 8.0


signal stamp_added(stamp: LDStamp)
signal stamp_removed(stamp_id: String)
signal stamp_changed(stamp: LDStamp)
signal instance_placed(stamp: LDStamp, unique_id: String)
signal instance_removed(stamp: LDStamp, unique_id: String)
signal armed_stamp_changed(stamp: LDStamp)


var _stamps: Dictionary[String, LDStamp] = {}
var _armed_stamp: LDStamp = null


func _on_ready() -> void:
	# Persist stamps into the session as soon as they change, so they survive an
	# editor reload even if the user never explicitly saves the level.
	stamp_added.connect(_persist_session.unbind(1))
	stamp_removed.connect(_persist_session.unbind(1))
	stamp_changed.connect(_persist_session.unbind(1))
	instance_placed.connect(_persist_session.unbind(2))
	instance_removed.connect(_persist_session.unbind(2))


func _persist_session() -> void:
	LD.get_save_load_handler().save_session()


## The area a stamp instance lives in, by name (falls back to the active area for legacy instances
## saved before stamps were area-aware).
func _area_for_name(area_name: String) -> LDArea:
	for area: LDArea in LDLevel._inst.get_areas():
		if area.area_name == area_name:
			return area
	return LDLevel.get_active_area()


## Repoints stamp instances placed in a renamed area (the per-area key and each placed object's
## address) so they still rehydrate into it.
func rename_area_references(old_name: String, new_name: String) -> void:
	for stamp: LDStamp in _stamps.values():
		if stamp.instances.has(old_name):
			var arr: Array = stamp.instances[old_name]
			stamp.instances.erase(old_name)
			if stamp.instances.has(new_name):
				(stamp.instances[new_name] as Array).append_array(arr)
			else:
				stamp.instances[new_name] = arr
	for obj: LDObject in _all_objects():
		var parts: PackedStringArray = get_object_linked_stamp(obj).split(":")
		if parts.size() == 3 and parts[1] == old_name:
			obj.set_meta(&"linked_stamp", parts[0] + ":" + new_name + ":" + parts[2])


## Every object across every area (stamp instances can live in any area, not just the active one).
func _all_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	for area: LDArea in LDLevel._inst.get_areas():
		result.append_array(area.get_all_objects())
	return result


func get_stamp(id: String) -> LDStamp:
	return _stamps.get(id, null)


func get_all_stamps() -> Array[LDStamp]:
	var result: Array[LDStamp] = []
	for stamp: LDStamp in _stamps.values():
		result.append(stamp)
	return result


## Stamps marked indexable, i.e. the ones the object browser lists for placement. Stamp definitions
## are shared across all areas (only their placed instances are per-area).
func get_indexable_stamps() -> Array[LDStamp]:
	return get_all_stamps().filter(func(stamp: LDStamp) -> bool: return stamp.indexable)


## Toggles whether a stamp shows up in the object browser.
func set_indexable(id: String, value: bool) -> void:
	var stamp: LDStamp = get_stamp(id)
	if not stamp or stamp.indexable == value:
		return
	stamp.indexable = value
	stamp_changed.emit(stamp)


func has_stamp(id: String) -> bool:
	return _stamps.has(id)


## A free default id ("stamp_1", "stamp_2", ...) for a brand-new stamp.
func suggest_stamp_id() -> String:
	var index: int = 1
	while has_stamp("stamp_" + str(index)):
		index += 1
	return "stamp_" + str(index)


## Arms a stamp for click-to-place via the Place tool. Pass null to disarm.
func arm_stamp(stamp: LDStamp) -> void:
	_armed_stamp = stamp
	armed_stamp_changed.emit(stamp)


func get_armed_stamp() -> LDStamp:
	return _armed_stamp


func remove_stamp(id: String) -> void:
	if not has_stamp(id):
		return

	_dehydrate_stamp(id)
	_stamps.erase(id)
	stamp_removed.emit(id)


func rename_stamp(old_id: String, new_id: String) -> bool:
	if not has_stamp(old_id) or has_stamp(new_id):
		return false

	var stamp: LDStamp = _stamps[old_id]
	stamp.id = new_id
	_stamps[new_id] = stamp
	_stamps.erase(old_id)

	# Re-point placed instances ("old_id:unique" -> "new_id:unique") across every area.
	for obj: LDObject in _all_objects():
		var linked: String = get_object_linked_stamp(obj)
		if linked.begins_with(old_id + ":"):
			obj.set_meta(&"linked_stamp", new_id + linked.substr(old_id.length()))

	stamp_changed.emit(stamp)
	return true


## Creates (or, when `id` names an existing stamp, replaces) a stamp from an immutable
## snapshot of the given objects. The originals are left untouched; the stamp stores
## serialized copies (relative to their centroid) that get spawned as instances wherever
## the stamp is placed. Replacing an existing stamp re-renders its placed instances.
## Returns null if nothing stampable was selected.
func create_stamp_from_objects(objects: Array[LDObject], id: String = "") -> LDStamp:
	var save_load: LDSaveLoadHandler = LD.get_save_load_handler()

	var stampable: Array[LDObject] = []
	for obj: LDObject in objects:
		var game_object: GameObject = save_load.find_game_object_for(obj)
		if game_object and game_object.ld_stampable:
			stampable.append(obj)
	if stampable.is_empty():
		return null

	var instance_pos: Vector2 = Vector2.ZERO
	for obj: LDObject in stampable:
		instance_pos += obj.position
	instance_pos /= float(stampable.size())

	# Layers are captured relative to the stamp's lowest layer, so placing the stamp on
	# layer N puts its objects on N, N+1, ... preserving their layer spacing.
	var base_layer: int = _get_object_layer_index(stampable[0])
	for obj: LDObject in stampable:
		base_layer = mini(base_layer, _get_object_layer_index(obj))

	var entries: Array[Dictionary] = []
	for obj: LDObject in stampable:
		var data: Dictionary = save_load._serialize_object(obj)
		if data.is_empty():
			continue
		data["local_offset"] = Packer.vec2_to_array(obj.position - instance_pos)
		data["layer_offset"] = _get_object_layer_index(obj) - base_layer
		entries.append(data)
	if entries.is_empty():
		return null

	if id.is_empty():
		id = suggest_stamp_id()

	var stamp: LDStamp = get_stamp(id)
	var is_new: bool = stamp == null
	if is_new:
		stamp = LDStamp.new()
		stamp.id = id
		_stamps[id] = stamp

	stamp.objects = entries

	if is_new:
		stamp_added.emit(stamp)
	else:
		# Existing placements should reflect the new snapshot.
		_rehydrate_stamp(stamp)

	_request_preview(stamp)
	stamp_changed.emit(stamp)
	return stamp


## True if any of the stamp's instances are currently placed in the level.
func has_instances(stamp_id: String) -> bool:
	for obj: LDObject in _all_objects():
		if get_object_linked_stamp(obj).begins_with(stamp_id + ":"):
			return true
	return false


## "Instantiates" a stamp: detaches every placed instance into independent, editable
## objects (clearing their link + restoring color) and then drops the stamp itself.
func bake_stamp(stamp_id: String) -> void:
	if not has_stamp(stamp_id):
		return
	for obj: LDObject in _all_objects():
		if not get_object_linked_stamp(obj).begins_with(stamp_id + ":"):
			continue
		obj.remove_meta(&"linked_stamp")
		if obj.has_meta(&"linked_readonly"):
			obj.remove_meta(&"linked_readonly")
		obj.set_shader_parameter(&"saturation", 1.0)
	_stamps.erase(stamp_id)
	stamp_removed.emit(stamp_id)


func place_linked(stamp_id: String, unique_id: String, position: Vector2, layer_index: int) -> bool:
	var stamp: LDStamp = get_stamp(stamp_id)
	if not stamp:
		return false

	# A placed stamp belongs to whichever area is active at placement time, indexed within it.
	var area: LDArea = LDLevel.get_active_area()
	var area_name: String = area.area_name
	if stamp.has_instance(area_name, unique_id):
		return false

	var instance: Dictionary = stamp.add_instance(area_name, unique_id, position, layer_index)
	var spawned: Array[LDObject] = _spawn_stamp_objects(stamp, position, layer_index, false, area)

	var address: String = stamp.get_full_address(area_name, unique_id)
	for obj: LDObject in spawned:
		_mark_linked_object(obj, address)

	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Place Stamp: " + address)
	history.add_do(func() -> void:
		if not stamp.has_instance(area_name, unique_id):
			if not stamp.instances.has(area_name):
				stamp.instances[area_name] = []
			stamp.instances[area_name].append(instance)
		for obj: LDObject in spawned:
			if is_instance_valid(obj) and not obj.get_parent():
				var obj_layer: int = obj.get_meta(&"spawn_layer", layer_index)
				area.add_object(obj, Vector2i(obj.position), obj_layer)
		instance_placed.emit(stamp, unique_id)
	)
	history.add_undo(func() -> void:
		stamp.remove_instance(area_name, unique_id)
		for obj: LDObject in spawned:
			if is_instance_valid(obj) and obj.get_parent():
				obj.get_parent().remove_child(obj)
		instance_removed.emit(stamp, unique_id)
	)
	history.commit_action()

	instance_placed.emit(stamp, unique_id)
	return true


func remove_instance(stamp_id: String, area_name: String, unique_id: String) -> void:
	var stamp: LDStamp = get_stamp(stamp_id)
	if not stamp:
		return

	var address: String = stamp.get_full_address(area_name, unique_id)
	var existing: Dictionary = stamp.get_instance(area_name, unique_id)
	var inst_pos: Vector2 = Packer.array_to_vec2(existing.get("position", [0.0, 0.0]))
	var inst_layer: int = int(existing.get("layer_index", 0))
	var area: LDArea = _area_for_name(area_name)
	var to_remove: Array[LDObject] = _get_objects_at_address(address)

	var history: LDHistoryHandler = LD.get_history_handler()
	history.begin_action("Remove Instance: " + address)
	history.add_do(func() -> void:
		stamp.remove_instance(area_name, unique_id)
		for obj: LDObject in to_remove:
			if is_instance_valid(obj) and obj.get_parent():
				obj.get_parent().remove_child(obj)
		instance_removed.emit(stamp, unique_id)
	)
	history.add_undo(func() -> void:
		stamp.add_instance(area_name, unique_id, inst_pos, inst_layer)
		for obj: LDObject in to_remove:
			if is_instance_valid(obj) and not obj.get_parent():
				var obj_layer: int = obj.get_meta(&"spawn_layer", inst_layer)
				area.add_object(obj, Vector2i(obj.position), obj_layer)
		instance_placed.emit(stamp, unique_id)
	)
	history.commit_action()

	stamp.remove_instance(area_name, unique_id)
	for obj: LDObject in to_remove:
		if is_instance_valid(obj) and obj.get_parent():
			obj.get_parent().remove_child(obj)

	instance_removed.emit(stamp, unique_id)


func get_object_linked_stamp(obj: LDObject) -> String:
	return str(obj.get_meta(&"linked_stamp", ""))


## Tags a spawned stamp object with its instance address. Every instance is a grayscale,
## read-only snapshot copy - a stamp is an immutable snapshot, so there is no editable
## "primary".
func _mark_linked_object(obj: LDObject, address: String) -> void:
	obj.set_meta(&"linked_stamp", address)
	obj.set_meta(&"linked_readonly", true)
	obj.set_shader_parameter(&"saturation", 0.0)


## True if obj is a read-only "ghost" copy of a placed stamp instance.
func is_linked_readonly(obj: LDObject) -> bool:
	return bool(obj.get_meta(&"linked_readonly", false))


## All placed objects belonging to the same stamp instance as obj (used to
## select/move/delete a stamp placement as a single unit).
func get_linked_instance_objects(obj: LDObject) -> Array[LDObject]:
	var address: String = get_object_linked_stamp(obj)
	if address.is_empty():
		return []
	return _get_objects_at_address(address)


## Removes the entire stamp instance that obj belongs to (and its objects).
func remove_instance_for_object(obj: LDObject) -> void:
	var parts: PackedStringArray = get_object_linked_stamp(obj).split(":")
	if parts.size() < 3:
		return
	remove_instance(parts[0], parts[1], parts[2])


## World position of the instance that obj's stamp instance is placed at.
func get_instance_position_for_object(obj: LDObject) -> Vector2:
	var parts: PackedStringArray = get_object_linked_stamp(obj).split(":")
	if parts.size() < 3:
		return Vector2.ZERO
	var stamp: LDStamp = get_stamp(parts[0])
	if not stamp:
		return Vector2.ZERO
	var instance: Dictionary = stamp.get_instance(parts[1], parts[2])
	if instance.is_empty():
		return Vector2.ZERO
	return Packer.array_to_vec2(instance.get("position", [0.0, 0.0]))


## Updates the stored position of a stamp instance (so a moved instance persists/rehydrates
## in its new spot). Address is "stamp_id:area_name:unique_id".
func set_instance_position_by_address(address: String, pos: Vector2) -> void:
	var parts: PackedStringArray = address.split(":")
	if parts.size() < 3:
		return
	var stamp: LDStamp = get_stamp(parts[0])
	if not stamp:
		return
	var instance: Dictionary = stamp.get_instance(parts[1], parts[2])
	if not instance.is_empty():
		instance["position"] = [pos.x, pos.y]


func serialize_all() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for stamp: LDStamp in _stamps.values():
		result.append(stamp.serialize())
	return result


func deserialize_all(data: Array) -> void:
	_stamps.clear()
	for entry: Variant in data:
		if not entry is Dictionary:
			continue
		var stamp: LDStamp = LDStamp.deserialize(entry)
		if stamp.id.is_empty():
			continue
		_stamps[stamp.id] = stamp

	for stamp: LDStamp in _stamps.values():
		_request_preview(stamp)


func generate_preview(stamp: LDStamp) -> void:
	if stamp.objects.is_empty():
		stamp.preview_texture = null
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

	for entry: Dictionary in stamp.objects:
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
		stamp.preview_texture = null
		return

	var content_size: Vector2 = (bounds_max - bounds_min).max(Vector2(1.0, 1.0))
	var available: float = float(PREVIEW_SIZE) - PREVIEW_PADDING * 2.0
	var scale_factor: float = minf(available / content_size.x, available / content_size.y)

	var center: Vector2 = (bounds_min + bounds_max) * 0.5
	root.scale = Vector2(scale_factor, scale_factor)
	root.position = Vector2(PREVIEW_SIZE, PREVIEW_SIZE) * 0.5 - center * scale_factor

	await RenderingServer.frame_post_draw

	var img: Image = viewport.get_texture().get_image()
	stamp.preview_texture = ImageTexture.create_from_image(img)

	viewport.queue_free()
	stamp_changed.emit(stamp)


func _request_preview(stamp: LDStamp) -> void:
	generate_preview(stamp)


func rehydrate_all() -> void:
	for stamp: LDStamp in _stamps.values():
		_rehydrate_stamp(stamp)


func _rehydrate_stamp(stamp: LDStamp) -> void:
	_dehydrate_stamp(stamp.id)

	for area_name: String in stamp.instances:
		var area: LDArea = _area_for_name(area_name)
		for instance: Dictionary in stamp.get_area_instances(area_name):
			var unique_id: String = str(instance.get("unique_id", ""))
			var instance_pos: Vector2 = Packer.array_to_vec2(instance.get("position", [0.0, 0.0]))
			var instance_layer: int = instance.get("layer_index", 0)
			var address: String = stamp.get_full_address(area_name, unique_id)
			var spawned: Array[LDObject] = _spawn_stamp_objects(stamp, instance_pos, instance_layer, false, area)

			for obj: LDObject in spawned:
				_mark_linked_object(obj, address)


func _dehydrate_stamp(stamp_id: String) -> void:
	for obj: LDObject in _all_objects():
		if get_object_linked_stamp(obj).begins_with(stamp_id + ":"):
			if obj.get_parent():
				obj.get_parent().remove_child(obj)
			# Free it, not just detach: a detached-but-live instance keeps its signal
			# connections and can resurface, so deletions wouldn't stick.
			obj.queue_free()


## Spawns one preview (ghost) instance per object in the stamp, positioned relative to
## instance_pos. The instances are flagged as previews and are NOT committed to history;
## the caller owns them and should free them. Reposition with position_preview().
func spawn_preview(stamp: LDStamp, instance_pos: Vector2) -> Array[LDObject]:
	if not stamp:
		return []
	var area: LDArea = LDLevel.get_active_area()
	return _spawn_stamp_objects(stamp, instance_pos, area._active_index, true, area)


## Moves a set of preview instances (from spawn_preview) so the stamp sits at instance_pos.
func position_preview(instances: Array[LDObject], instance_pos: Vector2) -> void:
	for instance: LDObject in instances:
		if not is_instance_valid(instance):
			continue
		instance.position = instance_pos + instance.get_meta(&"preview_offset", Vector2.ZERO)


func _spawn_stamp_objects(stamp: LDStamp, instance_pos: Vector2, default_layer: int = 0, as_preview: bool = false, area: LDArea = null) -> Array[LDObject]:
	var result: Array[LDObject] = []
	var db: GameDB = GameDB.get_db()
	if not area:
		area = LDLevel.get_active_area()
	var save_load: LDSaveLoadHandler = LD.get_save_load_handler()

	for entry: Dictionary in stamp.objects:
		var object_id: String = entry.get("object_id", "")
		var game_object: GameObject = save_load.find_game_object_by_id(object_id, db)
		if not game_object:
			continue

		var instance: LDObject = game_object.get_editor_instance()
		if not instance:
			continue
		instance.is_preview = as_preview
		var local_offset: Vector2 = Packer.array_to_vec2(entry.get("local_offset", [0.0, 0.0]))
		var obj_layer: int = default_layer + int(entry.get("layer_offset", 0))
		var world_pos: Vector2 = instance_pos + local_offset

		area.add_object(instance, Vector2i(world_pos), obj_layer)
		instance.init_properties(game_object)

		var props: Dictionary = entry.get("properties", {})
		for key: String in props:
			# The captured "position" is the object's original absolute position; the
			# spawn position comes from instance + local_offset, so don't restore it here.
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


func _get_objects_at_address(address: String) -> Array[LDObject]:
	var result: Array[LDObject] = []
	for obj: LDObject in _all_objects():
		if get_object_linked_stamp(obj) == address:
			result.append(obj)
	return result


func _get_object_layer_index(obj: LDObject) -> int:
	for area: LDArea in LDLevel._inst.get_areas():
		for layer: LDLayer in area.layers:
			if obj.get_parent() == layer.get_objects_root():
				return layer.index
	return LDLevel.get_active_area()._active_index
