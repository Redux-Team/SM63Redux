@tool
class_name SettingsCategoryLevelDesigner
extends SettingsCategory

signal music_changed

const SHUFFLE: String = "Shuffle"
const OFF: String = "Off"

@export var tooltip_delay: SettingsTypeFloat
@export var editor_music: SettingsTypeList
@export var loop_music: SettingsTypeBoolean


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var options: PackedStringArray = PackedStringArray([SHUFFLE])
	for track: MusicTrack in MusicDB.get_tracks_in(MusicTrack.Category.EDITOR):
		options.append(track.display_name)
	options.append(OFF)
	editor_music.options = options


func _apply_setting(setting: SettingsType) -> void:
	match setting:
		editor_music, loop_music:
			music_changed.emit()
		_:
			super(setting)


func is_tooltip_enabled() -> bool:
	return tooltip_delay.current_value < tooltip_delay.maximum


func get_editor_tracks() -> Array[MusicTrack]:
	var tracks: Array[MusicTrack] = MusicDB.get_tracks_in(MusicTrack.Category.EDITOR)
	match editor_music.option():
		SHUFFLE:
			return tracks
		OFF:
			return []
	
	var picked: Array[MusicTrack] = []
	picked.assign(tracks.filter(
			func(track: MusicTrack) -> bool:
				return track.display_name == editor_music.option()
	))
	return picked
