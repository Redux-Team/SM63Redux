class_name MusicDB

const TRACKS_DIR: String = "res://game/music/tracks"

static var _tracks: Array[MusicTrack] = []


static func get_track(id: StringName) -> MusicTrack:
	for track: MusicTrack in get_tracks():
		if track.id == id:
			return track
	
	return null


static func get_tracks() -> Array[MusicTrack]:
	if _tracks.is_empty():
		for file: String in ResourceLoader.list_directory(TRACKS_DIR):
			var track: MusicTrack = load(TRACKS_DIR.path_join(file)) as MusicTrack
			if track:
				_tracks.append(track)
		_tracks.sort_custom(
				func(a: MusicTrack, b: MusicTrack) -> bool:
					return a.display_name < b.display_name
		)
	
	return _tracks


static func get_tracks_in(category: MusicTrack.Category) -> Array[MusicTrack]:
	var tracks: Array[MusicTrack] = []
	tracks.assign(
			get_tracks().filter(
					func(track: MusicTrack) -> bool:
						return track.category == category
	))
	return tracks
