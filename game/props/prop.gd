class_name Prop
extends Node2D

@export var disabled: bool = false:
	set(value):
		disabled = value
		process_mode = Node.PROCESS_MODE_DISABLED if disabled else Node.PROCESS_MODE_INHERIT

var object: GameObject


func _enter_tree() -> void:
	if object:
		return
	
	object = GameObject.of(get_parent())
	if object:
		object.value_changed.connect(_on_property_changed)


func _ready() -> void:
	_on_init()


func get_property(key: StringName, fallback: Variant = null) -> Variant:
	var value: Variant = object.get_value(key) if object else null
	return fallback if value == null else value


func _on_init() -> void:
	pass


func _on_property_changed(_key: StringName, _value: Variant) -> void:
	pass
