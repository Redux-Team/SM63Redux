class_name MusicTrack
extends Resource

enum Category {
	LEVEL,
	EDITOR,
}

@export var id: StringName
@export var display_name: String
@export var category: Category = Category.LEVEL
@export_file("*.mp3", "*.ogg") var path: String
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var loop_offset: float = 0.0

var _looped: AudioStream


func get_stream() -> AudioStream:
	return load(path) as AudioStream


func get_looped_stream() -> AudioStream:
	if _looped == null:
		_looped = get_stream().duplicate() as AudioStream
		_looped.set(&"loop", true)
		_looped.set(&"loop_offset", loop_offset)
	return _looped
