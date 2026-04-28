## Area responsible for receiving damage.
@icon("uid://dl48gyw37ryc4")
class_name HurtBox
extends Area2D

signal damaged(source_hitbox: HitBox)


## Hitbox IDs to ignore
@export var ignored_hitbox_ids: PackedStringArray
## Leave empty to ignore none
@export var ignored_damage_types: Array[HitBox.DamageType]
## Leave emtpy to accept all
@export var accepted_damage_types: Array[HitBox.DamageType]
## State to change to when damaged
@export var damage_state: State


func _init() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 4
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if area is not HitBox:
		return
	var hitbox: HitBox = area as HitBox
	
	# Validity checks
	if hitbox.hitbox_id in ignored_hitbox_ids:
		return
	if hitbox.damage_type in ignored_damage_types:
		return
	if not accepted_damage_types.is_empty() and hitbox.damage_type not in accepted_damage_types:
		return
	
	if owner is Entity:
		var entity: Entity = owner as Entity
		if entity.has_component(HealthComponent):
			var health_component: HealthComponent = entity.get_component(HealthComponent)
			
			health_component.hp -= hitbox.damage_amount
			print(hitbox.global_position - global_position)
			entity.velocity -= hitbox.knockback_vector * sign(hitbox.global_position - global_position)
			
			if damage_state and entity.state_machine:
				entity.state_machine.change_state(damage_state.state_name)
	
	damaged.emit(hitbox)
