class_name GravityComponent
extends EntityComponent


@export var strength: float = 15.0
@export var scale_factor: float = 1.0

var _locks: int = 0
var _modifiers: Dictionary[StringName, float] = {}


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


func set_modifier(key: StringName, scale: float) -> void:
	_modifiers[key] = scale


func clear_modifier(key: StringName) -> void:
	_modifiers.erase(key)


func get_effective_strength() -> float:
	return strength * scale_factor


func _physics_process(_delta: float) -> void:
	if enabled and entity:
		entity.velocity.y += (strength * scale_factor)
