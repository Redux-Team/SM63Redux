@warning_ignore_start("unused_parameter", "unused_private_class_variable")
@abstract class_name Entity
extends CharacterBody2D


enum DamageType {
	GENERIC,
	SQUASH,
	STRIKE
}


@export var sprite: SmartSprite2D
@export var components_root: Node
var components: Array[EntityComponent]


func _ready() -> void:
	for child: Node in components_root.get_children():
		if child is EntityComponent:
			child.entity = self


func _physics_process(delta: float) -> void:
	_on_tick(delta)
	if Engine.is_editor_hint():
		return
	_gravity_handler()
	move_and_slide()


func get_component(type: Script) -> EntityComponent:
	if not components_root:
		return null
	for child: Node in components_root.get_children():
		if is_instance_of(child, type):
			return child as EntityComponent
	return null


func damage(amount: float, type: DamageType, source: Node2D = null) -> void:
	var invulnerability: InvulnerabilityComponent = get_component(InvulnerabilityComponent)
	if not invulnerability or invulnerability.can_receive(type):
		force_damage(amount, type, source)


func force_damage(amount: float, type: DamageType, source: Node2D = null) -> void:
	var health: HealthComponent = get_component(HealthComponent)
	if not health:
		return
	health.hp -= amount
	_on_damage(amount, type, source)
	if health.hp <= 0.0:
		_on_death(type, source)


func kill() -> void:
	var health: HealthComponent = get_component(HealthComponent)
	if not health:
		return
	health.hp = 0.0
	_on_death(DamageType.GENERIC)


func _on_tick(delta: float) -> void:
	pass


func _on_death(type: DamageType, source: Node2D = null) -> void:
	queue_free()


func _on_damage(amount: float, type: DamageType, source: Node2D = null) -> void:
	pass


func _gravity_handler() -> void:
	pass
