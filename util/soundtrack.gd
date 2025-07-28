class_name Soundtrack
extends Object


const LevelDesigner: Dictionary = {
		"track_1": "uid://bkqa0virm1d5x",
		"track_2": "uid://bdt5br8e3u3h5",
		"track_3": "uid://bwrrxonh0o0ww",
		"track_4": "uid://demm0md11iu5c",
}


static func pick_random(playlist: Dictionary) -> AudioStream:
	return load(playlist.get(playlist.keys()[randi_range(0, playlist.size() - 1)]))
