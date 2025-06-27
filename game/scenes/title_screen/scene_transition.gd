extends Node

@export var menu_loop: AudioStreamPlayer

const LEVEL_DESIGNER_SCENE: String = "uid://c732aftmb2bcv"
const TRANSITION_MASK: CompressedTexture2D = preload("uid://b127vhuh31i8r")

func transition(type: MainMenuButton.ButtonDesign) -> void:
	match type:
		MainMenuButton.ButtonDesign.LEVEL_DESIGNER:
			owner.input_locked = true
			
			Singleton.transition_to_scene_file(
				LEVEL_DESIGNER_SCENE,
				Singleton.ScreenTransitionType.TEXTURE_ZOOM,
				TRANSITION_MASK,
				0.5,
			)
			
			SFX.play(SFX.UI_START)
			menu_loop.stop()
