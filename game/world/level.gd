class_name Level
extends Node


enum FileFormat {
	BINARY,
	JSON
}

@export var _data: LevelData
@export var _area_ref: LevelArea
@warning_ignore("unused_private_class_variable")
@export var _music_player: AudioStreamPlayer
@export var _camera: Camera2D


func get_data() -> LevelData:
	return _data


func get_loaded_area() -> LevelArea:
	return _area_ref


func get_camera() -> LevelCamera:
	return _camera


func change_area() -> void:
	pass
