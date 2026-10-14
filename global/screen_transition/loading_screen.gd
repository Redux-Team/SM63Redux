class_name LoadingScreen
extends ColorRect

@export var sprite: SmartSprite2D
@export var fade_duration: float = 0.25

var _tween: Tween


func open() -> void:
	if visible:
		return
	
	sprite.play(Array(sprite.diffuse_frames.get_animation_names()).pick_random())
	modulate.a = 0.0
	show()
	await _fade(1.0).finished


func close() -> void:
	if not visible:
		return
	
	if _tween and _tween.is_running():
		await _tween.finished
	await _fade(0.0).finished
	hide()
	sprite.stop()


func _fade(alpha: float) -> Tween:
	if _tween:
		_tween.kill()
	
	_tween = create_tween()
	_tween.tween_property(self, ^"modulate:a", alpha, fade_duration)
	return _tween
