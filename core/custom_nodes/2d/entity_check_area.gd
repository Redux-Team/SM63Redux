class_name EntityCheckArea
extends Area2D

signal entity_entered(entity: Entity)
signal player_entered(player: Player)

var _players_inside: Array[Player] = []
var _entities_inside: Array[Entity] = []


func _ready() -> void:
	set_deferred(&"monitorable", false)
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func _on_area_entered(area: Area2D) -> void:
	if not (area.has_meta(&"entity_region") and area.owner is Entity):
		return
	
	var entity: Entity = area.owner as Entity
	
	_entities_inside.append(entity)
	entity_entered.emit(entity)
	
	if entity is Player:
		var player: Player = entity as Player
		_players_inside.append(player)
		player_entered.emit(player)


func _on_area_exited(area: Area2D) -> void:
	if not (area.has_meta(&"entity_region") and area.owner is Entity):
		return
	
	var entity: Entity = area.owner as Entity
	
	_entities_inside.erase(entity)
	
	if entity is Player:
		_players_inside.erase(entity as Player)


func is_player_inside() -> bool:
	return not _players_inside.is_empty()


func get_first_player() -> Player:
	return _players_inside.front()


func get_closest_player(origin: Vector2) -> Player:
	var closest: Player = null
	var closest_dist: float = INF
	for player: Player in _players_inside:
		var d: float = origin.distance_squared_to(player.global_position)
		if d < closest_dist:
			closest_dist = d
			closest = player
	return closest


func get_entities() -> Array[Entity]:
	return _entities_inside


func disable() -> void:
	set_deferred(&"monitoring", false)


func enable() -> void:
	set_deferred(&"monitoring", true)
