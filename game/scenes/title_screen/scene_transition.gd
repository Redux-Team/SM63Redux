extends Control

@export var mask: ColorRect
@export var sfx_begin: AudioStreamPlayer
@export var menu_loop: AudioStreamPlayer

var tween: Tween

func transition(type: MainMenuButton.ButtonDesign) -> void:
	match type:
		MainMenuButton.ButtonDesign.STORY:
			owner.input_locked = true
			sfx_begin.play()
			menu_loop.stop()
			show()
			tween = get_tree().create_tween().bind_node(mask)
			tween.set_ease(Tween.EASE_OUT)
			tween.tween_property(mask, ^"material:shader_parameter/scale", 0.0, 0.5)
			tween.finished.connect(switch_to_story)


func switch_to_story() -> void:
	await get_tree().create_timer(0.5).timeout
	get_tree().change_scene_to_file("uid://cfrexipnk4yq8")
