@tool
class_name SettingsCategoryAudio
extends SettingsCategory

@export var output_device: SettingsTypeList
@export var master_volume: SettingsTypeFloat
@export var music_volume: SettingsTypeFloat
@export var sfx_volume: SettingsTypeFloat
@export var player_volume: SettingsTypeFloat


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var devices: PackedStringArray = PackedStringArray()
	devices.append_array(AudioServer.get_output_device_list())
	output_device.options = devices


func _apply_setting(setting: SettingsType) -> void:
	match setting:
		output_device:
			AudioServer.output_device = output_device.options.get(output_device.current_value)
		master_volume:
			_apply_bus(&"Master", master_volume)
		music_volume:
			_apply_bus(&"Music", music_volume)
		sfx_volume:
			_apply_bus(&"SFX", sfx_volume)
		player_volume:
			_apply_bus(&"Player", player_volume)
		_:
			super(setting)


func _apply_bus(bus: StringName, volume: SettingsTypeFloat) -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(bus),
		lerpf(-60, 0, volume.current_value / 100.0)
	)
