class_name PlayerHUD
extends CanvasLayer

@export var player: Player
@export var health_meter: HealthMeter
@export var fludd_meter: FluddMeter
@export var coin_counters: Dictionary[StringName, CoinCounter] = {}


func _ready() -> void:
	if player:
		bind(player)


func bind(target: Player) -> void:
	player = target
	health_meter.bind(target.get_component(HealthComponent) as HealthComponent)
	health_meter.bind_caps(target.caps)
	fludd_meter.bind(target.fludd)


func set_coins(kind: StringName, count: int, total: int = 0) -> void:
	var counter: CoinCounter = coin_counters.get(kind)
	if counter:
		counter.set_count(count, total)
