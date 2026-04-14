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


var data: Dictionary
var properties: Dictionary[StringName, Variant] = {}
var source_object_id: String = ""
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


func init_from_data(obj_data: Dictionary) -> void:
	data = obj_data
	source_object_id = obj_data.get("object_id", "")
	var props: Dictionary = obj_data.get("properties", {})
	for key: String in props:
		properties[key] = props[key]
	position = _array_to_vec2(obj_data.get("position", [0.0, 0.0]))
	_on_init()


func get_property(key: StringName) -> Variant:
	return properties.get(key)


func set_property(key: StringName, value: Variant) -> void:
	properties[key] = value
	_on_property_changed(key, value)


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


func _on_init() -> void:
	pass


func _on_tick(delta: float) -> void:
	pass


func _on_death(type: DamageType, source: Node2D = null) -> void:
	queue_free()


func _on_damage(amount: float, type: DamageType, source: Node2D = null) -> void:
	pass


func _on_property_changed(_key: StringName, _value: Variant) -> void:
	pass


func _gravity_handler() -> void:
	pass


func _array_to_vec2(a: Variant) -> Vector2:
	if a is Array and a.size() >= 2:
		return Vector2(float(a[0]), float(a[1]))
	return Vector2.ZERO


func _array_to_packed_vec2(a: Variant) -> PackedVector2Array:
	var packed: PackedVector2Array = []
	if a is Array and a.size() >= 1:
		for v_a: Array in a:
			packed.append(Vector2(float(v_a[0]), float(v_a[1])))
	return packed
