class_name IngameHUD
extends CanvasLayer


@export var health_gradient: Gradient
@export var inner_hp_texture: ColorRect
@export var inner_hpbg: TextureRect
@export var yellow_coin_label: RichTextLabel
@export var red_coin_container: HBoxContainer
@export var red_coin_label: RichTextLabel
@export var purple_coin_container: HBoxContainer
@export var purple_coin_label: RichTextLabel
@export var power: SmartSprite2D
@export var coin_meter: SmartSprite2D
@export var health_container: Control


const HEALTH_HIDE_DELAY: float = 4.0
const HEALTH_TWEEN_DURATION: float = 0.3


var health_component: HealthComponent
var _coin_counter_tweens: Dictionary[RichTextLabel, Tween] = {}
var _coin_flash_tweens: Dictionary[RichTextLabel, Tween] = {}
var _health_hide_timer: float = 0.0
var _health_visible: bool = true
var _health_tween: Tween
var _yellow_coin_counter: int = 0:
	set(ycc):
		_yellow_coin_counter = ycc
		yellow_coin_label.text = str(ycc)
var _red_coin_counter: int = 0:
	set(rcc):
		_red_coin_counter = rcc
		var max_amount: int = Level.get_instance().get_red_coin_max("default")
		if max_amount == 0:
			red_coin_container.hide()
			return
		red_coin_label.text = "%d[font_size=24]/%d" % [rcc, max_amount]
var _purple_coin_counter: int = 0:
	set(pcc):
		_purple_coin_counter = pcc
		var max_amount: int = Level.get_instance().get_purple_coin_max("default")
		if max_amount == 0:
			purple_coin_container.hide()
			return
		purple_coin_label.text = "%d[font_size=24]/%d" % [pcc, max_amount]
var _power_resetting: bool = false


func _ready() -> void:
	Level.get_instance().yellow_coin_count_updated.connect(_on_yellow_coins_updated)
	Level.get_instance().red_coin_count_updated.connect(_on_red_coins_updated)
	Level.get_instance().purple_coin_count_updated.connect(_on_purple_coins_updated)
	
	Level.get_instance().on_load(func() -> void:
		_red_coin_counter = 0
		_purple_coin_counter = 0
	)


func _process(delta: float) -> void:
	if health_component == null:
		return
	if health_component.get_hp() >= health_component.max_hp and _health_visible:
		_health_hide_timer += delta
		if _health_hide_timer >= HEALTH_HIDE_DELAY:
			_set_health_visible(false)
	else:
		_health_hide_timer = 0.0
	


func bind(entity: Entity) -> void:
	health_component = entity.get_component(HealthComponent)
	health_component.hp_updated.connect(_on_hp_updated)
	health_component.power_updated.connect(_on_power_updated)
	health_component.power_reset.connect(_on_power_reset)
	_on_hp_updated(health_component.get_hp())
	_on_power_updated(0)


func _on_yellow_coins_updated() -> void:
	_update_coin_counter(yellow_coin_label, ^"_yellow_coin_counter", Level.get_instance().get_yellow_coin_count())


func _on_red_coins_updated() -> void:
	_update_coin_counter(red_coin_label, ^"_red_coin_counter", Level.get_instance().get_red_coin_count("default"))


func _on_purple_coins_updated() -> void:
	_update_coin_counter(purple_coin_label, ^"_purple_coin_counter", Level.get_instance().get_purple_coin_count("default"))


func _on_hp_updated(amount: float) -> void:
	var mat: ShaderMaterial = inner_hp_texture.material as ShaderMaterial
	var total: float = health_component.max_hp
	var pct: float = amount / float(health_component.max_hp)
	var filled: int = roundi(pct * float(total))
	var col: Color = health_gradient.sample(1.0 - pct) if amount > 1 else health_gradient.sample(0.85)
	mat.set_shader_parameter("total_slices", int(total))
	mat.set_shader_parameter("filled_slices", filled)
	mat.set_shader_parameter("modulate_color", col)
	inner_hpbg.modulate = col
	
	if amount < health_component.max_hp:
		_health_hide_timer = 0.0
		_set_health_visible(true)


func _on_power_updated(amount: int) -> void:
	if _power_resetting:
		return
	power.current_animation = "default"
	power.current_frame = amount
	coin_meter.current_animation = "default"
	coin_meter.current_frame = amount


func _on_power_reset() -> void:
	if _power_resetting:
		return
	_power_resetting = true
	
	# We have to pass it in as an array since arrays are passed by reference
	var finished: Array[int] = [0]
	var on_finished: Callable = func() -> void:
		finished[0] += 1
		if finished[0] >= 2:
			_power_resetting = false
			power.current_animation = "default"
			power.current_frame = health_component.power
			coin_meter.current_animation = "default"
			coin_meter.current_frame = health_component.power
	
	power.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)
	coin_meter.animation_finished.connect(on_finished, CONNECT_ONE_SHOT)
	power.play(&"heal")
	coin_meter.play(&"heal")


func _set_health_visible(health_visible: bool) -> void:
	if _health_visible == health_visible:
		return
	_health_visible = health_visible
	if _health_tween:
		_health_tween.kill()
	_health_tween = create_tween().set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_CUBIC)
	var target_anchor: float = 0.0 if health_visible else -0.3
	_health_tween.tween_property(health_container, ^"anchor_top", target_anchor, HEALTH_TWEEN_DURATION)
	_health_tween.parallel().tween_property(health_container, ^"anchor_bottom", target_anchor, HEALTH_TWEEN_DURATION)


func _update_coin_counter(label: RichTextLabel, property: NodePath, amount: int) -> void:
	var counter_tween: Tween = _coin_counter_tweens.get(label)
	if counter_tween:
		counter_tween.kill()
	counter_tween = create_tween()
	counter_tween.tween_property(self, property, amount, 0.15)
	_coin_counter_tweens[label] = counter_tween
	_pulse_label(label)


func _pulse_label(label: RichTextLabel) -> void:
	var flash_tween: Tween = _coin_flash_tweens.get(label)
	if flash_tween:
		flash_tween.kill()
	flash_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var tint: Color = label.get_meta(&"tint_color", Color.WHITE)
	flash_tween.tween_property(label, ^"modulate", tint, 0.1)
	flash_tween.tween_property(label, ^"modulate", Color.WHITE, 0.1)
	_coin_flash_tweens[label] = flash_tween
