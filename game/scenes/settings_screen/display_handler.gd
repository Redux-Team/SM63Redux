extends Node

const FPS_OPTIONS: Array[int] = [30, 60, 120, 240, 0]
const WINDOW_OPTIONS: Array[String] = ["Windowed", "Fullscreen", "Fullscreen Borderless"]

@export var fps_dropdown: OptionButton
@export var win_mode_dropdown: OptionButton
@export var vsync_entry: BooleanSettingEntry


func _ready() -> void:
	fps_dropdown.select(FPS_OPTIONS.find(Config.display.max_fps))
	win_mode_dropdown.select(WINDOW_OPTIONS.find(Config.display.window_mode))
	vsync_entry.value = Config.display.vsync


func _on_fps_option_button_item_selected(index: int) -> void:
	Config.display.max_fps = FPS_OPTIONS[index]
	Config.apply()


func _on_win_mode_option_button_item_selected(index: int) -> void:
	Config.display.window_mode = WINDOW_OPTIONS[index]
	Config.apply()


func _on_v_sync_value_changed(value: bool) -> void:
	Config.display.vsync = value
	Config.apply()
