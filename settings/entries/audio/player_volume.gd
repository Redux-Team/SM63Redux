@tool
extends SettingsTypeFloat


func apply() -> void:
	AudioServer.set_bus_volume_db(
		AudioServer.get_bus_index(&"Player"),
		lerpf(-60, 0, current_value / 100.0)
	)
