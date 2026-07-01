class_name LDMusic
extends Resource


enum UnderwaterMode {
	MUFFLE,
	TRACK,
	IGNORE,
}


## Display name when this resource is a preset (empty for the working copy / custom music).
@export var preset_name: String = ""
@export var underwater_mode: UnderwaterMode = UnderwaterMode.MUFFLE
@export var subtracks: Array[LDMusicSubtrack] = []


func is_empty() -> bool:
	return subtracks.is_empty()


func working_copy() -> LDMusic:
	var copy: LDMusic = deserialize(serialize())
	copy.preset_name = preset_name
	return copy


func serialize() -> Dictionary:
	var result: Array = []
	for subtrack: LDMusicSubtrack in subtracks:
		result.append(subtrack.serialize())
	return {
		"underwater_mode": int(underwater_mode),
		"subtracks": result,
	}


static func deserialize(data: Variant) -> LDMusic:
	var music: LDMusic = LDMusic.new()
	var entries: Variant = data
	if data is Dictionary:
		music.underwater_mode = int((data as Dictionary).get("underwater_mode", UnderwaterMode.MUFFLE))
		entries = (data as Dictionary).get("subtracks", [])
	if entries is Array:
		for entry: Variant in entries:
			if entry is Dictionary:
				music.subtracks.append(LDMusicSubtrack.deserialize(entry))
	return music
