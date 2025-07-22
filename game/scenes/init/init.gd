extends Control


func _ready() -> void:
	Config.load()
	Config.apply()
	
	if Device.is_mobile():
		Singleton.current_input_device = Singleton.InputType.TOUCHSCREEN
	
	call_deferred(&"change_to_title_screen")


func change_to_title_screen() -> void:
	Singleton.transition_to_scene_file(
		"uid://b0wp6l07i5ime",
		Singleton.ScreenTransitionType.TEXTURE_ZOOM,
		load("uid://b127vhuh31i8r"),
		0.5,
		false
	)
