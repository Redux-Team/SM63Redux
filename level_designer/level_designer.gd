extends Control

@export var ld_music: AudioStreamPlayer

var leaving: bool = false


func _ready() -> void:
	ld_music.stream = Soundtrack.pick_random(Soundtrack.LevelDesigner)
	await get_tree().create_timer(1).timeout
	ld_music.play()


func _on_button_pressed() -> void:
	if leaving:
		return
	
	.play(SFX.UI_BACK)
	Singleton.transition_to_scene_file(
		"uid://b0wp6l07i5ime",
		Singleton.ScreenTransitionType.TEXTURE_ZOOM,
		load("uid://b7hhchui2qslg"),
		0.7
	)
	
	ld_music.stop()
	leaving = true
