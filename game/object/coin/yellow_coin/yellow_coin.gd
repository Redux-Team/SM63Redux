class_name YellowCoin
extends Coin

@export var coin_amount: int = 1
@export var power_amount: int = 1
@export var fludd_power_amount: float = 10.0
@export var purple: bool = false
@export var purple_group: String = "default"


func _ready() -> void:
	super()
	if purple:
		Level.get_instance().add_purple_coin_max(purple_group)


func explode(strength_x: float = 0.0, strength_y: float = 0.0) -> void:
	super(strength_x, strength_y)
	collision_mask = 2


func _on_entity_check_area_player_entered(_player: Player) -> void:
	_spawn_collect_particles()
	sfx_player.play()
	
	if purple:
		Level.get_instance().add_purple_coin(purple_group)
	else:
		Level.get_instance().add_yellow_coin(coin_amount)
		Level.get_player().add_power(power_amount)
		Level.get_player().add_fludd_power(fludd_power_amount)
	
	_hide_and_disable()
	
	await sfx_player.finished
	queue_free()
