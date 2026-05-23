class_name EntityCheckArea
extends Area2D

signal entity_entered(entity: Entity)
signal player_entered(player: Player)


func _ready() -> void:
	set_deferred(&"monitorable", false)
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area.has_meta(&"entity_region") and area.owner is Entity:
		var entity: Entity = area.owner as Entity
		
		entity_entered.emit(entity)
		
		if entity is Player:
			player_entered.emit(entity as Player)


func disable() -> void:
	set_deferred(&"monitoring", false)


func enable() -> void:
	set_deferred(&"monitoring", true)
