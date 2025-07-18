extends Node

signal input_type_changed
@warning_ignore("unused_signal") signal control_scheme_changed

enum ScreenTransitionType {
	TEXTURE_ZOOM
} 

enum InputType {
	KEYBOARD,
	CONTROLLER,
	TOUCHSCREEN,
	UNKNOWN
}

var version: String = ProjectSettings.get("application/config/version")

@export var sfx_container: Node
@export var transition_overlay: ColorRect
@export var touch_screen_layer: CanvasLayer

var current_input_device: InputType = InputType.KEYBOARD
var _last_device_type: InputType


func _process(_delta: float) -> void:
	_check_touch_display(current_input_device)


func _input(event: InputEvent) -> void:
	_check_input_device(event)


func transition_to_scene_file(scene_file: String, transition: ScreenTransitionType, texture: Texture2D = Texture2D.new(), time: float = 1.0) -> void:
	match transition:
		ScreenTransitionType.TEXTURE_ZOOM when time and texture:
			var tween: Tween = get_tree().create_tween()
			tween.bind_node(transition_overlay)
			tween.set_ease(Tween.EASE_OUT)
			
			var mat = ShaderMaterial.new()
			mat.shader = Shaders.INVERSE_CLIP
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
				
				# Holding the transition before switching to next scene
				# so that it's not as abrupt.
				await get_tree().create_timer(0.15).timeout
				
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


func get_active_input_device() -> String:
	return InputType.keys()[current_input_device].to_pascal_case()


func show_touch_screen_layer() -> void:
	if Config.input.touch_screen_scene == null:
		return
	
	for child: Node in touch_screen_layer.get_children():
		child.queue_free()
	
	var touch_screen: TouchScreen = Config.input.touch_screen_scene.duplicate(true).instantiate()
	touch_screen.preview = false
	
	touch_screen_layer.add_child(touch_screen)
	touch_screen_layer.show()


func hide_touch_screen_layer() -> void:
	touch_screen_layer.hide()


func _check_input_device(event: InputEvent) -> void:
	if event is InputEventMouse:
		return
	
	if event is InputEventKey:
		current_input_device = InputType.KEYBOARD
	
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadMotion and abs(event.axis_value) < 0.5:
				return
		current_input_device = InputType.CONTROLLER
	
	elif event is InputEventScreenTouch or event is InputEventScreenDrag:
		current_input_device = InputType.TOUCHSCREEN
	
	else:
		current_input_device = InputType.UNKNOWN
	
	
	if current_input_device == _last_device_type:
		return
	
	_last_device_type = current_input_device
	input_type_changed.emit()


func _check_touch_display(device: InputType) -> void:
	if device == InputType.TOUCHSCREEN or Config.misc.enforce_touch_display:
		for control: Control in get_tree().get_nodes_in_group(&"gui_touch"):
			control.show()
	else:
		for control: Control in get_tree().get_nodes_in_group(&"gui_touch"):
			control.hide()


func _play_sfx(stream: AudioStream) -> void:
	var audio_stream_player: AudioStreamPlayer = AudioStreamPlayer.new()
	audio_stream_player.bus = &"SFX"
	audio_stream_player.stream = stream
	
	sfx_container.add_child(audio_stream_player)
	
	audio_stream_player.finished.connect(func() -> void:
		audio_stream_player.queue_free()
	)
	
	audio_stream_player.play()
