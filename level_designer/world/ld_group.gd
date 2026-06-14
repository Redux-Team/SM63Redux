class_name LDGroup
extends Resource


@export var id: String = ""
@export var objects: Array[Dictionary] = []
@export var anchors: Array[Dictionary] = []

var preview_texture: ImageTexture = null


func get_anchor(unique_id: String) -> Dictionary:
	for anchor: Dictionary in anchors:
		if anchor.get("unique_id", "") == unique_id:
			return anchor
	return {}


func has_anchor(unique_id: String) -> bool:
	return not get_anchor(unique_id).is_empty()


func add_anchor(unique_id: String, position: Vector2, layer_index: int) -> Dictionary:
	var anchor: Dictionary = {
		"unique_id": unique_id,
		"position": [position.x, position.y],
		"layer_index": layer_index,
		"overrides": {},
	}
	anchors.append(anchor)
	return anchor


func remove_anchor(unique_id: String) -> void:
	for i: int in anchors.size():
		if anchors[i].get("unique_id", "") == unique_id:
			anchors.remove_at(i)
			return


func get_full_address(unique_id: String) -> String:
	return id + ":" + unique_id


func is_anchor_address(address: String) -> bool:
	return address.contains(":")


func serialize() -> Dictionary:
	return {
		"id": id,
		"objects": objects.duplicate(true),
		"anchors": anchors.duplicate(true),
	}


static func deserialize(data: Dictionary) -> LDGroup:
	var group: LDGroup = LDGroup.new()
	group.id = data.get("id", "")
	group.objects = data.get("objects", []).duplicate(true)
	group.anchors = data.get("anchors", []).duplicate(true)
	return group
