extends Node

const FPS_OPTIONS: Array[int] = [30, 60, 120, 240, 0]

@export var fps_dropdown: DropdownSettingEntry
@export var win_mode_dropdown: DropdownSettingEntry
@export var vsync_entry: BooleanSettingEntry
@export var ui_scale_slider: SliderSettingEntry


func _ready() -> void:
	fps_dropdown.selected_index = FPS_OPTIONS.find(Config.display.max_fps)
	win_mode_dropdown.selected_index = Config.display.window_mode
	vsync_entry.value = Config.display.vsync
	ui_scale_slider.slider_value = Config.display.ui_scale
	
	if Device.is_mobile():
		win_mode_dropdown.hide()
		vsync_entry.hide()


func _on_fps_limit_option_selected(index: int) -> void:
	Config.display.max_fps = FPS_OPTIONS[index]
	Config.apply()


func _on_win_mode_option_selected(index: int) -> void:
	Config.display.window_mode = index
	Config.apply()


func _on_v_sync_value_changed(value: bool) -> void:
	Config.display.vsync = value
	Config.apply()


func _on_ui_scale_drag_ended() -> void:
	Config.display.ui_scale = ui_scale_slider.slider_value
	Config.apply()
