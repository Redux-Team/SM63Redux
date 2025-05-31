extends Node

enum ScreenTransitionType {
	TEXTURE_ZOOM
} 

const VERSION: StringName = &"0.2.0"

@export var sfx_container: Node
@export var transition_overlay: ColorRect


func play_sfx(stream: AudioStream) -> void:
	var audio_stream_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_stream_player.bus = &"SFX"
	audio_stream_player.stream = stream
	
	sfx_container.add_child(audio_stream_player)
	
	audio_stream_player.finished.connect(func() -> void:
		audio_stream_player.queue_free()
	)
	
	audio_stream_player.play()


func transition_to_scene_file(scene_file: String, transition: ScreenTransitionType, texture: Texture2D = Texture2D.new(), time: float = 1.0) -> void:
	match transition:
		ScreenTransitionType.TEXTURE_ZOOM when time and texture:
			var tween: Tween = get_tree().create_tween()
			tween.bind_node(transition_overlay)
			tween.set_ease(Tween.EASE_OUT)
			
			var mat = ShaderMaterial.new()
			mat.shader = load("uid://dig60ar7inm7i")
			mat.set_shader_parameter(&"texture_albedo", texture)
			transition_overlay.material = mat
			transition_overlay.show()
			
			tween.tween_method(
				func(value):
					mat.set_shader_parameter(&"scale", value),
				3.0, 0.0, time
			)
			
			tween.finished.connect(func() -> void:
				get_tree().change_scene_to_file(scene_file)
				
				var second_tween: Tween = get_tree().create_tween()
				second_tween.bind_node(transition_overlay)
				second_tween.set_ease(Tween.EASE_OUT)
				second_tween.tween_method(
					func(value):
						mat.set_shader_parameter(&"scale", value),
					0.0, 3.0, time
				)
				
				second_tween.finished.connect(func() -> void: transition_overlay.hide(), CONNECT_ONE_SHOT)
			, CONNECT_ONE_SHOT)



func _screen_transition_texture_zoom() -> void:
	pass
