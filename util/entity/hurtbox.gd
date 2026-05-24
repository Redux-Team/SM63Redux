@icon("uid://dl48gyw37ryc4")
class_name HurtBox
extends Area2D

signal damaged(source_hitbox: HitBox)

@export_group("Filtering")
## Hitbox IDs that are always rejected before component matching.
@export var ignored_hitbox_ids: PackedStringArray
## Damage types that are always rejected before component matching.
@export var ignored_damage_types: Array[HitBox.DamageType]

@export_group("Components")
## Evaluated in order; first match wins.
@export var components: Array[HurtBoxComponent]

@export_group("Defaults")
@export var default_damage_state: StringName
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "default_knockback") var has_default_knockback: bool = false
@export var default_knockback: Vector2 = Vector2(150, 135)
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "disable_on_hit") var disable_on_hit: bool = false
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var disable_on_hit_duration: float = 0.0


func _init() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 4
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is not HitBox:
		return
	var hitbox: HitBox = area as HitBox
	
	if not hitbox.is_valid():
		return
	if hitbox.hitbox_ids.any(func(id: String) -> bool: return id in ignored_hitbox_ids):
		return
	if hitbox.damage_type in ignored_damage_types:
		return
	
	for component: HurtBoxComponent in components:
		if not component.matches(hitbox, self, owner as Entity if owner is Entity else null):
			continue
		if owner is Entity:
			component.process(hitbox, self, owner as Entity)
		if disable_on_hit:
			disable()
			if disable_on_hit_duration > 0.0:
				enable(disable_on_hit_duration)
		damaged.emit(hitbox)
		return


func enable(time: float = 0.0) -> void:
	for c: Node in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred(&"disabled", false)
	set_deferred(&"monitorable", true)
	
	if time:
		await get_tree().create_timer(time).timeout
		disable()


func disable() -> void:
	for c: Node in get_children():
		if c is CollisionShape2D or c is CollisionPolygon2D:
			c.set_deferred(&"disabled", true)
	set_deferred(&"monitorable", true)
