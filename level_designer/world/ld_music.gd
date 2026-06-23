class_name LDMusic
extends Resource


@export var layers: Array[LDMusicLayer] = []


func is_empty() -> bool:
	return layers.is_empty()


func working_copy() -> LDMusic:
	return deserialize(serialize())


func serialize() -> Array:
	var result: Array = []
	for layer: LDMusicLayer in layers:
		result.append(layer.serialize())
	return result


static func deserialize(data: Variant) -> LDMusic:
	var music: LDMusic = LDMusic.new()
	if data is Array:
		for entry: Variant in data:
			if entry is Dictionary:
				music.layers.append(LDMusicLayer.deserialize(entry))
	return music
