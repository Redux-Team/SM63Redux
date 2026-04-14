class_name TitleSplashScreen
extends Control

@warning_ignore("unused_signal") signal intro_sequence_done

@export var animation_player: AnimationPlayer
@export var _63_sheen: TextureRect
@export var _redux_sheen: TextureRect

var _sheened_63: bool = false
var _sheened_redux: bool = false


func play_in_animation() -> void:
	animation_player.play(&"splash_in")


func play_glow_loop_animation() -> void:
	animation_player.play(&"glow_loop")


func sheen_63() -> void:
	_63_sheen.set_instance_shader_parameter(&"color_offset", Vector2(0.0, 0.0))
	
	var tween: Tween = get_tree().create_tween()
	
	tween.tween_method(
		func(y_value: float) -> void:
			var current = _63_sheen.get_instance_shader_parameter(&"color_offset")
			current.y = y_value
			_63_sheen.set_instance_shader_parameter(&"color_offset", current),
		0.0, 1.0, 0.85
	)
	
	tween.finished.connect(func() -> void:
		await get_tree().create_timer(randf_range(3.0, 6.0)).timeout
		sheen_63()
	)
	
	_sheened_63 = true


func sheen_redux() -> void:
	_redux_sheen.set_instance_shader_parameter(&"color_offset", Vector2(0.275, 0.0))
	
	var tween: Tween = get_tree().create_tween()
	
	tween.tween_method(
		func(y_value: float) -> void:
			var current = _redux_sheen.get_instance_shader_parameter(&"color_offset")
			current.y = y_value
			_redux_sheen.set_instance_shader_parameter(&"color_offset", current),
		0.275, 1.0, 0.65
	)
	
	tween.finished.connect(func() -> void:
		await get_tree().create_timer(randf_range(3.0, 6.0)).timeout
		sheen_redux()
	)
	
	_sheened_redux = true
