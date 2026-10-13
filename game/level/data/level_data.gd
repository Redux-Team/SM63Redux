@tool
class_name LevelData
extends RefCounted

const VERSION: int = 2

var version: int = VERSION
var level_name: String = ""
var areas: Array[AreaData] = []
var editor: Dictionary = {}
var extras: Dictionary = {}


static func create() -> LevelData:
	var data: LevelData = LevelData.new()
	data.areas.append(AreaData.create("Area 1"))
	return data


static func from_dict(dict: Dictionary) -> LevelData:
	var file_version: int = dict.get("version", 0)
	if file_version != VERSION:
		push_error("LevelData: unsupported level version %d. Convert older levels with dev/tools/ld_v1_migrator." % file_version)
		return null
	
	var data: LevelData = LevelData.new()
	data.level_name = dict.get("name", "")
	data.editor = dict.get("editor", {})
	data.extras = dict.get("extras", {})
	for area: Dictionary in dict.get("areas", []):
		data.areas.append(AreaData.from_dict(area))
	return data


func to_dict() -> Dictionary:
	var area_dicts: Array[Dictionary] = []
	for area: AreaData in areas:
		area_dicts.append(area.to_dict())
	
	return {
		"version": version,
		"name": level_name,
		"areas": area_dicts,
		"editor": editor,
		"extras": extras,
	}


func find_area(area_uuid: StringName) -> AreaData:
	for area: AreaData in areas:
		if area.uuid == area_uuid:
			return area
	
	return null
