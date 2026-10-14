class_name YellowCoin
extends Coin

@export var coin_amount: int = 1
@export var power_amount: int = 1
@export var fludd_power_amount: float = 10.0
@export var purple: bool = false
@export var group: StringName = &"default"


func _on_init() -> void:
	super()
	var level: Level = Level.of(self)
	if purple and level:
		level.register_coin(&"purple", group)


func explode(strength_x: float = 0.0, strength_y: float = 0.0) -> void:
	super(strength_x, strength_y)
	collision_mask = 2


func _on_entity_check_area_player_entered(player: Player) -> void:
	_spawn_collect_particles()
	sfx_player.play()
	var level: Level = Level.of(self)
	if purple:
		if level:
			level.collect_coin(&"purple", 1, group)
	else:
		reward(player, coin_amount, power_amount, fludd_power_amount)
	
	_hide_and_disable()
	await sfx_player.finished
	queue_free()
