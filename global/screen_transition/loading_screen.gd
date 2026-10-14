class_name LoadingScreen
extends ColorRect

@export var sprite: SmartSprite2D
@export var indicator: Control
@export var centered_offset: Vector2 = Vector2(67, -8)
@export var corner_alpha: float = 0.3137255
@export var fade_duration: float = 0.25
@export var blur_tint: Color = Color(0.106, 0.165, 0.255, 0.55)
@export var solid_tint: Color = Color.BLACK

var _tween: Tween
var _centered: bool = false


func open(blurred: bool = false) -> void:
	if visible:
		return
	
	(material as ShaderMaterial).set_shader_parameter(&"tint", blur_tint if blurred else solid_tint)
	_place_indicator(blurred)
	sprite.play(Array(sprite.diffuse_frames.get_animation_names()).pick_random())
	modulate.a = 0.0
	show()
	await _fade(1.0).finished


func close() -> void:
	if not visible:
		return
	
	if _tween and _tween.is_running():
		await _tween.finished
	if _centered:
		_tween = create_tween()
		_tween.tween_property(indicator, ^"modulate:a", 0.0, fade_duration)
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


func _place_indicator(centered: bool) -> void:
	_centered = centered
	if centered:
		indicator.set_anchors_preset(Control.PRESET_CENTER)
		indicator.position = get_rect().size * 0.5 + centered_offset
	else:
		indicator.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		indicator.position = get_rect().size - indicator.size - Vector2(2, 0)
	indicator.modulate.a = 1.0 if centered else corner_alpha
