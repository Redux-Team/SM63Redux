class_name RideArea
extends Area2D


signal new_player_rider(player: Player)
signal new_entity_rider(entity: Entity)
signal player_rider_exited(player: Player)
signal entity_rider_exited(entity: Entity)
signal riders_updated(riders: Array[Entity])


var bodies: Array[Entity]
var _signalled: Array[Entity]


func _init() -> void:
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func has_rider() -> bool:
	for rider: Entity in bodies:
		if rider.is_on_floor():
			return true
	return false


func get_riders() -> Array[Entity]:
	var riders: Array[Entity]
	for rider: Entity in bodies:
		if rider.is_on_floor():
			riders.append(rider)
	return riders


func get_entity_offset(entity: Entity) -> Vector2:
	return entity.global_position - global_position


func _physics_process(_delta: float) -> void:
	for body: Entity in bodies:
		if body.is_on_floor() and body not in _signalled:
			_signalled.append(body)
			if body is Player:
				new_player_rider.emit(body)
			new_entity_rider.emit(body)
	
	riders_updated.emit(get_riders())


func _on_area_entered(area: Area2D) -> void:
	var entity: Entity = area.owner as Entity
	if entity and entity != owner and entity not in bodies:
		bodies.append(entity)


func _on_area_exited(area: Area2D) -> void:
	var entity: Entity = area.owner as Entity
	if entity in bodies:
		bodies.erase(entity)
	if entity in _signalled:
		_signalled.erase(entity)
		if entity is Player:
			player_rider_exited.emit(entity as Player)
		entity_rider_exited.emit(entity)
