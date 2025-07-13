extends Node

const FPS_OPTIONS: Array[int] = [30, 60, 120, 240, 0]

@export var fps_dropdown: DropdownSettingEntry
@export var win_mode_dropdown: DropdownSettingEntry
@export var vsync_entry: BooleanSettingEntry


func _ready() -> void:
	fps_dropdown.selected_index = FPS_OPTIONS.find(Config.display.max_fps)
	win_mode_dropdown.selected_index = Config.display.window_mode
	vsync_entry.value = Config.display.vsync
	pass


func _on_fps_limit_option_selected(index: int) -> void:
	Config.display.max_fps = FPS_OPTIONS[index]
	Config.apply()
	pass


func _on_win_mode_option_selected(index: int) -> void:
	Config.display.window_mode = index
	Config.apply()
	pass


func _on_v_sync_value_changed(value: bool) -> void:
	Config.display.vsync = value
	Config.apply()
	pass
