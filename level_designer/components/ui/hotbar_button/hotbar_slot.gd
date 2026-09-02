class_name LDHotbarSlot
extends RefCounted


enum Kind {
	EMPTY,
	OBJECT,
	STAMP,
	GROUP,
}


var kind: Kind = Kind.EMPTY
var object_id: String = ""
var stamp_id: String = ""
var group: LDStamp = null


static func deserialize(data: Dictionary) -> LDHotbarSlot:
	var slot: LDHotbarSlot = LDHotbarSlot.new()
	if data.has("slot_data") or not data.has("kind"):
		slot._deserialize_legacy(data)
		return slot
	
	match str(data.get("kind", "")):
		"object":
			slot.set_object(str(data.get("object_id", "")))
		"stamp":
			slot.set_stamp(str(data.get("stamp_id", "")))
		"group":
			var entries: Array[Dictionary] = []
			for entry: Variant in data.get("group", []):
				if entry is Dictionary:
					entries.append(entry)
			slot.set_group(LDStampHandler.stamp_from_entries(entries))
	return slot


func is_empty() -> bool:
	return kind == Kind.EMPTY


func clear() -> void:
	kind = Kind.EMPTY
	object_id = ""
	stamp_id = ""
	group = null


func set_object(id: String) -> void:
	clear()
	if id.is_empty():
		return
	kind = Kind.OBJECT
	object_id = id


func set_stamp(id: String) -> void:
	clear()
	if id.is_empty():
		return
	kind = Kind.STAMP
	stamp_id = id


func set_group(stamp: LDStamp) -> void:
	clear()
	if not stamp or stamp.objects.is_empty():
		return
	kind = Kind.GROUP
	group = stamp


func get_count() -> int:
	return group.objects.size() if kind == Kind.GROUP and group else 0


func get_icon() -> Texture2D:
	match kind:
		Kind.OBJECT:
			var obj: GameObject = GameDB.get_object(object_id)
			return obj.get_entry_texture() if obj else null
		Kind.STAMP:
			var stamp: LDStamp = LD.get_stamp_handler().get_stamp(stamp_id)
			return stamp.preview_texture if stamp else null
		Kind.GROUP:
			return group.preview_texture if group else null
	return null


func get_label() -> String:
	match kind:
		Kind.OBJECT:
			var obj: GameObject = GameDB.get_object(object_id)
			return obj.get_object_name() if obj else object_id
		Kind.STAMP:
			return stamp_id
		Kind.GROUP:
			if get_count() == 1:
				var single: GameObject = GameDB.get_object(str(group.objects.front().get("object_id", "")))
				return single.get_object_name() if single else "Group of 1"
			return "Group of %d" % get_count()
	return ""


func is_valid() -> bool:
	match kind:
		Kind.OBJECT:
			return GameDB.get_object(object_id) != null
		Kind.STAMP:
			return LD.get_stamp_handler().has_stamp(stamp_id)
		Kind.GROUP:
			return group != null and not group.objects.is_empty()
	return true


func serialize() -> Dictionary:
	match kind:
		Kind.OBJECT:
			return {"kind": "object", "object_id": object_id}
		Kind.STAMP:
			return {"kind": "stamp", "stamp_id": stamp_id}
		Kind.GROUP:
			return {"kind": "group", "group": group.objects.duplicate(true)}
	return {"kind": "empty"}


func _deserialize_legacy(data: Dictionary) -> void:
	var legacy_stamp: String = str(data.get("stamp_id", ""))
	if not legacy_stamp.is_empty():
		set_stamp(legacy_stamp)
		return
	
	var entries: Array[Dictionary] = []
	for entry: Variant in data.get("slot_data", []):
		if entry is Dictionary:
			entries.append(entry)
	
	if entries.size() == 1:
		set_object(str(entries.front().get("object_id", "")))
	elif entries.size() > 1:
		set_group(LDStampHandler.stamp_from_entries(_relative_to_centroid(entries)))


func _relative_to_centroid(entries: Array[Dictionary]) -> Array[Dictionary]:
	var centroid: Vector2 = Vector2.ZERO
	for entry: Dictionary in entries:
		centroid += Packer.array_to_vec2(entry.get("position", [0.0, 0.0]))
	centroid /= float(entries.size())
	
	var result: Array[Dictionary] = []
	for entry: Dictionary in entries:
		var copy: Dictionary = entry.duplicate(true)
		copy["local_offset"] = Packer.vec2_to_array(Packer.array_to_vec2(entry.get("position", [0.0, 0.0])) - centroid)
		copy["layer_offset"] = 0
		result.append(copy)
	return result
