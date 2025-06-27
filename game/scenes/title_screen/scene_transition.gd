extends Node

@export var menu_loop: AudioStreamPlayer


func transition(type: MainMenuButton.ButtonDesign) -> void:
	match type:
		MainMenuButton.ButtonDesign.LEVEL_DESIGNER:
			owner.input_locked = true
			
			Singleton.transition_to_scene_file(
				"uid://c732aftmb2bcv",
				Singleton.ScreenTransitionType.TEXTURE_ZOOM,
				load("uid://b127vhuh31i8r"),
				0.5,
			)
			
			SFX.play(SFX.UI_START)
			menu_loop.stop()
