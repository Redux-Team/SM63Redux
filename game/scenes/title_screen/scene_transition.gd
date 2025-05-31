extends Node

@export var menu_loop: AudioStreamPlayer


func transition(type: MainMenuButton.ButtonDesign) -> void:
	match type:
		MainMenuButton.ButtonDesign.STORY:
			owner.input_locked = true
			
			Singleton.transition_to_scene_file(
				"uid://cfrexipnk4yq8",
				Singleton.ScreenTransitionType.TEXTURE_ZOOM,
				load("uid://b127vhuh31i8r"),
				0.5,
			)
			
			Singleton.play_sfx(SFX.UI_START)
			menu_loop.stop()
