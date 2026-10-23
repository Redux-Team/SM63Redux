class_name FluddMeter
extends Control

@export var tank: TextureRect
@export var nozzle_icon: AnimatedSprite2D
@export_group("Fuel")
@export var fuel_rect: ColorRect
@export var fuel_label: Label
@export var fuel_color: Color
@export var fuel_full_color: Color
@export var fuel_label_flash: Color
@export var fuel_min_height: float = 11.0
@export var fuel_max_height: float = 91.0
@export var fuel_top_offset: float = 9.5
@export_group("Power")
@export var power_meter: TextureRect
@export var power_scroll: ScrollingTexture2D
@export var power_clip: ClippingTexture2D
@export var power_full_color: Color
@export var power_scroll_speed: float = -0.8
@export_group("Animation")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var fill_time: float = 0.2
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var flash_in_time: float = 0.05
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var flash_out_time: float = 0.15
@export_group("Bob")
@export var bob_amplitude: float = 3.0
@export var bob_speed: float = 2.0
@export var bob_speed_spraying: float = 18.0
@export var bob_nozzles: Array[PlayerFludd.Nozzle] = [
	PlayerFludd.Nozzle.HOVER,
	PlayerFludd.Nozzle.TURBO,
]

var _fludd: PlayerFludd
var _fuel: float = 0.0
var _power: float = 0.0
var _bob_phase: float = 0.0
var _bob_rate: float = 0.0
var _fuel_tween: Tween
var _power_tween: Tween


func _process(delta: float) -> void:
	power_scroll.scroll.y += power_scroll_speed * delta
	_bob_phase = fmod(_bob_phase + _bob_rate * delta, TAU)
	nozzle_icon.position = Vector2(0.0, bob_amplitude * sin(_bob_phase))


func bind(fludd: PlayerFludd) -> void:
	_fludd = fludd
	fludd.nozzle_changed.connect(_on_nozzle_changed)
	fludd.fuel_changed.connect(_on_fuel_changed)
	fludd.power_changed.connect(_on_power_changed)
	fludd.spraying_changed.connect(_on_spraying_changed)
	_on_nozzle_changed(fludd.equipped_nozzle)
	_on_spraying_changed(fludd.is_spraying())
	_set_fuel(fludd.fuel / PlayerFludd.FUEL_MAX)
	_set_power(fludd.power / PlayerFludd.POWER_MAX)


func _on_nozzle_changed(nozzle: PlayerFludd.Nozzle) -> void:
	tank.visible = nozzle != PlayerFludd.Nozzle.NONE
	if tank.visible:
		nozzle_icon.frame = nozzle - 1
	_on_spraying_changed(_fludd.is_spraying())


func _on_spraying_changed(spraying: bool) -> void:
	_bob_rate = (
			bob_speed_spraying
			if spraying and bob_nozzles.has(_fludd.equipped_nozzle)
			else bob_speed
	)


func _on_fuel_changed(fuel: float) -> void:
	var ratio: float = fuel / PlayerFludd.FUEL_MAX
	if ratio >= _fuel:
		var flash: Tween = create_tween().set_parallel()
		flash.tween_property(fuel_rect, ^"color", fuel_full_color, flash_in_time)
		flash.tween_property(fuel_label, ^"modulate", fuel_label_flash, flash_in_time)
		flash.chain().tween_property(fuel_rect, ^"color", fuel_color, flash_out_time)
		flash.tween_property(fuel_label, ^"modulate", Color.WHITE, flash_out_time)
	
	if _fuel_tween:
		_fuel_tween.kill()
	_fuel_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_fuel_tween.tween_method(_set_fuel, _fuel, ratio, fill_time)


func _on_power_changed(power: float) -> void:
	var ratio: float = power / PlayerFludd.POWER_MAX
	if ratio >= 0.995 and _power < 0.995:
		var flash: Tween = create_tween()
		flash.tween_property(power_meter, ^"modulate", power_full_color, flash_out_time)
		flash.tween_property(power_meter, ^"modulate", Color.WHITE, flash_out_time)
	
	if _power_tween:
		_power_tween.kill()
	_power_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_power_tween.tween_method(_set_power, _power, ratio, fill_time)


func _set_fuel(ratio: float) -> void:
	_fuel = ratio
	fuel_rect.visible = ratio >= 0.01
	fuel_label.text = "MAX" if ratio >= 0.995 else "%d%%" % roundi(ratio * 100.0)
	if not fuel_rect.visible:
		return
	
	var height: float = lerpf(fuel_min_height, fuel_max_height, ratio)
	fuel_rect.set_deferred(&"size", Vector2(fuel_rect.size.x, height))
	fuel_rect.position.y = fuel_top_offset + fuel_max_height - height


func _set_power(ratio: float) -> void:
	_power = ratio
	power_clip.clip_ratio.y = ratio
