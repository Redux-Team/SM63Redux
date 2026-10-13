class_name GravityComponent
extends EntityComponent


@export var strength: float = 15.0
@export var scale_factor: float = 1.0
@export var direction: Vector2 = Vector2(0, 1)
@export var rotate_root: bool = true
@export var water_multiplier: float = 0.1

var modifiers: ModifierStack = ModifierStack.new()

var _locks: int = 0


func _init() -> void:
	set_process(false)
	set_physics_process(false)


func _ready() -> void:
	await owner.ready
	set_process(true)
	set_physics_process(true)


func lock() -> void:
	_locks += 1
	enabled = false


func unlock() -> void:
	_locks = max(_locks - 1, 0)
	if _locks == 0:
		enabled = true


func get_angle() -> float:
	return Vector2(0, 1).angle_to(direction)


func set_modifier(key: StringName, scale: float, duration: float = 0.0) -> void:
	modifiers.set_modifier(key, scale, duration)


func clear_modifier(key: StringName) -> void:
	modifiers.clear_modifier(key)


func get_effective_strength() -> float:
	return strength * scale_factor * modifiers.product()


func _process(_delta: float) -> void:
	if enabled and entity and rotate_root:
		entity.rotation = get_angle()
		entity.up_direction = direction.rotated(PI)


func _physics_process(delta: float) -> void:
	modifiers.tick(delta)
	if enabled and entity:
		entity.velocity.y += get_effective_strength() * (water_multiplier if entity.water_check and entity.is_in_water() else 1.0)
