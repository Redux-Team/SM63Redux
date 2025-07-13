class_name AudioConfig
extends Subconfig


@export var output_device: StringName = &"Default"
@export var music_on: bool = true
@export var sfx_on: bool = true
@export_range(0, 100) var music_volume: float = 75
@export_range(0, 100) var sfx_volume: float = 75


func apply() -> void:
	AudioServer.set_bus_mute(1, not music_on)
	AudioServer.set_bus_mute(2, not sfx_on)
	
	AudioServer.set_bus_volume_db(1, remap(music_volume, 0, 100, -60, 20))
	AudioServer.set_bus_volume_db(2, remap(sfx_volume, 0, 100, -60, 20))
	
	AudioServer.output_device = output_device
