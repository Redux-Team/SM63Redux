class_name HealthMeter
extends Control

@export var gradient: Gradient
@export_range(0.0, 1.0) var critical_gradient_offset: float = 0.85
@export var slices: ColorRect
@export var background: TextureRect
@export var power_sprite: SmartSprite2D
@export var coin_sprite: SmartSprite2D
@export_group("Auto Hide")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var hide_delay: float = 4.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var slide_time: float = 0.3
@export var hidden_anchor: float = -0.3

var _health: HealthComponent
var _shown: bool = true
var _slide: Tween
var _healing: int = 0


func bind(health: HealthComponent) -> void:
	_health = health
	health.hp_updated.connect(_on_hp_updated)
	health.power_updated.connect(_on_power_updated)
	health.power_reset.connect(_on_power_reset)
	_on_hp_updated(health.get_hp())
	_on_power_updated(health.power)


func _on_hp_updated(hp: float) -> void:
	var ratio: float = hp / _health.max_hp
	var color: Color = gradient.sample(1.0 - ratio if hp > 1.0 else critical_gradient_offset)
	var slice_material: ShaderMaterial = slices.material as ShaderMaterial
	slice_material.set_shader_parameter(&"total_slices", int(_health.max_hp))
	slice_material.set_shader_parameter(&"filled_slices", roundi(hp))
	slice_material.set_shader_parameter(&"modulate_color", color)
	background.modulate = color
	_slide_to(hp < _health.max_hp)


func _on_power_updated(power: int) -> void:
	if _healing > 0:
		return
	
	for sprite: SmartSprite2D in [power_sprite, coin_sprite]:
		sprite.current_animation = "default"
		sprite.current_frame = power


func _on_power_reset() -> void:
	if _healing > 0:
		return
	
	for sprite: SmartSprite2D in [power_sprite, coin_sprite]:
		_healing += 1
		sprite.animation_finished.connect(_on_heal_finished, CONNECT_ONE_SHOT)
		sprite.play(&"heal")


func _on_heal_finished() -> void:
	_healing -= 1
	if _healing == 0:
		_on_power_updated(_health.power)


func _slide_to(shown: bool) -> void:
	if shown == _shown:
		return
	
	_shown = shown
	if _slide:
		_slide.kill()
	
	var anchor: float = 0.0 if shown else hidden_anchor
	_slide = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	_slide.tween_interval(0.0 if shown else hide_delay)
	_slide.tween_property(self, ^"anchor_top", anchor, slide_time)
	_slide.parallel().tween_property(self, ^"anchor_bottom", anchor, slide_time)
