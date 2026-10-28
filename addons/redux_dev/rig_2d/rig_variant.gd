@tool
class_name RigVariant
extends Resource


@export var axis: StringName = &"":
	set(a):
		axis = a
		resource_name = "%s=%s" % [axis, value]
@export var value: StringName = &"":
	set(v):
		value = v
		resource_name = "%s=%s" % [axis, value]
@export var frames: SpriteFrames


func provides(rig: SpriteRig2D, animation: StringName) -> bool:
	return frames != null and rig.get_variant(axis) == value and frames.has_animation(animation)
