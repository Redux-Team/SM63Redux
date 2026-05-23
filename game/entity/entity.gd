## Base entity class, can hold [EntityComponent]s as well as
@warning_ignore_start("unused_parameter", "unused_private_class_variable")
@abstract class_name Entity
extends CharacterBody2D


@export var sprite: SmartSprite2D
@export var components_root: Node
@export var collision_shapes: Array[CollisionShape2D]
@export var state_machine: StateMachine
@export var exit_objects: Dictionary[PackedScene, int]


var data: Dictionary
var properties: Dictionary[StringName, Variant] = {}
var source_object_id: String = ""
var components: Array[EntityComponent]
var _velocity_lock: bool = false
var _exit_objs_spawned: bool = false

## Helper variable which takes into account the [member sprite]'s flip_h property.
var local_velocity: Vector2:
	get():
		if not sprite:
			return velocity
		
		return Vector2(
			velocity.x * (-1 if sprite.flip_h else 1),
			velocity.y
		)
	set(lv):
		if not sprite:
			velocity = lv
		
		velocity = Vector2(
			lv.x * (-1 if sprite.flip_h else 1),
			lv.y
		)


func _ready() -> void:
	if components_root:
		for child: Node in components_root.get_children():
			if child is EntityComponent:
				child.entity = self


func _physics_process(delta: float) -> void:
	_on_tick(delta)
	if Engine.is_editor_hint():
		return
	
	if has_component(GravityComponent):
		if not _velocity_lock:
			move_and_slide_with_gravity()
	else:
		if not _velocity_lock:
			move_and_slide()


func init_from_data(obj_data: Dictionary) -> void:
	data = obj_data
	source_object_id = obj_data.get("object_id", "")
	var props: Dictionary = obj_data.get("properties", {})
	for key: String in props:
		properties[key] = props[key]
	position = Packer.array_to_vec2(obj_data.get("position", [0.0, 0.0]))
	scale = Packer.array_to_vec2(properties.get("scale", [1.0, 1.0]))
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


func has_component(type: Script) -> bool:
	return get_component(type) != null


func damage(amount: float, type: HitBox.DamageType, source: Node2D = null) -> void:
	var invulnerability: InvulnerabilityComponent = get_component(InvulnerabilityComponent)
	if not invulnerability or invulnerability.can_receive(type):
		force_damage(amount, type, source)


func force_damage(amount: float, type: HitBox.DamageType, source: Node2D = null) -> void:
	var health: HealthComponent = get_component(HealthComponent)
	if not health:
		return
	health.damage(amount, type)
	_on_damage(amount, type, source)
	if health.hp <= 0.0:
		_on_death(type, source)


func kill() -> void:
	var health: HealthComponent = get_component(HealthComponent)
	if not health:
		return
	health.hp = 0.0
	_on_death(HitBox.DamageType.GENERIC)


func _on_init() -> void:
	pass


func _on_tick(delta: float) -> void:
	pass


func _on_death(type: HitBox.DamageType, source: Node2D = null) -> void:
	queue_free()


func _on_damage(amount: float, type: HitBox.DamageType, source: Node2D = null) -> void:
	pass


func _on_property_changed(_key: StringName, _value: Variant) -> void:
	pass


func disable() -> void:
	_velocity_lock = true
	for c: EntityComponent in components_root.get_children():
		c.enabled = false


func enable() -> void:
	_velocity_lock = false
	for c: EntityComponent in components_root.get_children():
		c.enabled = true


func get_active_state_uptime() -> float:
	return state_machine.get_current_state().get_elapsed_time()


func move_and_slide_with_gravity() -> void:
	var gravity: GravityComponent = get_component(GravityComponent)
	if not gravity:
		return
	var angle: float = gravity.get_angle()
	velocity = velocity.rotated(angle)
	move_and_slide()
	velocity = velocity.rotated(-angle)
	if sprite:
		up_direction = Vector2.UP.rotated(angle)
		rotation = angle


func spawn_exit_objects(shared_properties: Array = ["position", "scale", "rotation"]):
	if _exit_objs_spawned:
		return
	
	for packed: PackedScene in exit_objects:
		for i: int in exit_objects.get(packed):
			var node: Node = packed.instantiate().duplicate()
			Singleton.spawn_sibling(self, node, shared_properties)
	
	_exit_objs_spawned = true


func _exit_tree() -> void:
	spawn_exit_objects()
