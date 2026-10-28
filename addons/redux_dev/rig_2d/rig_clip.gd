@tool
class_name RigClip
extends Resource


@export var name: StringName = &"":
	set(n):
		name = n
		resource_name = n
@export var fps: float = 5.0
@export var loop: bool = true
