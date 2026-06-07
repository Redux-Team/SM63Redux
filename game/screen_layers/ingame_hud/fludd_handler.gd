extends Node

@export var fuel_color: Color
@export var fuel_max_color: Color
@export var power_max_color: Color

@export var tank: TextureRect
@export var fuel_rect: ColorRect
@export var fuel_label: Label
@export var fludd_nozzle_icon: AnimatedSprite2D
@export var power_meter: TextureRect
@export var power_scrolling_texture: ScrollingTexture2D
@export var power_clipping_texture: ClippingTexture2D


var _fuel: float = 0.0
var _power: float = 0.0

var fuel_percent_tween: Tween
var fuel_flash_tween: Tween

var power_percent_tween: Tween
var power_flash_tween: Tween


func _ready() -> void:
	Level.get_instance().on_load(func() -> void:
		var fludd_handler: PlayerFluddHandler = Level.get_player().get_fludd_handler()
		
		set_nozzle(fludd_handler.equipped_nozzle)
		fludd_handler.fludd_nozzle_changed.connect(set_nozzle)
		
		set_fuel_percent(fludd_handler.fludd_fuel)
		fludd_handler.fludd_fuel_changed.connect(_on_fuel_changed)
		
		set_power_percent(fludd_handler.fludd_power)
		fludd_handler.fludd_power_changed.connect(_on_power_changed)
	)


func _process(delta: float) -> void:
	const POWER_ANIMATION_RATE: float = -0.8
	power_scrolling_texture.scroll.y += POWER_ANIMATION_RATE * delta
	fludd_nozzle_icon.position = Vector2(0, 3 * sin(Time.get_ticks_msec() / 500.0))


func _on_fuel_changed(percentage: float) -> void:
	if _fuel <= percentage:
		fuel_flash_tween = create_tween()
		fuel_flash_tween.tween_property(fuel_rect, ^"color", fuel_max_color, 0.05)
		fuel_flash_tween.tween_property(fuel_rect, ^"color", fuel_color, 0.15)
	
	fuel_percent_tween = create_tween()
	fuel_percent_tween.tween_method(set_fuel_percent, _fuel, percentage, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func _on_power_changed(amount: float) -> void:
	if amount >= 99.5 and _power < 99.5:
		power_flash_tween = create_tween()
		power_flash_tween.tween_property(power_meter, ^"modulate", power_max_color, 0.15)
		power_flash_tween.tween_property(power_meter, ^"modulate", Color.WHITE, 0.15)
	
	power_percent_tween = create_tween()
	power_percent_tween.tween_method(set_power_percent, _power, amount, 0.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)


func set_fuel_percent(percentage: float) -> void:
	const MAX_HEIGHT: float = 91.0
	const MIN_HEIGHT: float = 11.0
	
	if percentage < 1.0:
		fuel_rect.hide()
	else:
		fuel_rect.show()
		var height: float = lerpf(MIN_HEIGHT, MAX_HEIGHT, percentage / 100.0)
		fuel_rect.size.y = height
		fuel_rect.position.y = 9.5 + (MAX_HEIGHT - height)
	fuel_label.text = "%s%%" % int(percentage)
	if percentage >= 99.5:
		fuel_label.text = "MAX"
	_fuel = percentage


func set_power_percent(percentage: float) -> void:
	power_clipping_texture.clip_ratio.y = percentage / 100.0
	_power = percentage


func set_nozzle(nozzle: PlayerFluddHandler.FluddNozzle) -> void:
	match nozzle:
		PlayerFluddHandler.FluddNozzle.NONE:
			tank.hide()
		_:
			tank.show()
			fludd_nozzle_icon.frame = nozzle - 1
