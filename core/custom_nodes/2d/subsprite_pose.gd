class_name SubspritePose
extends Resource


@export var offset: Vector2 = Vector2.ZERO
@export var rotation_degrees: float = 0.0
@export var visible: bool = true
@export var in_front: bool = false
## Overrides which animation the subsprite plays on this frame. Empty follows the root's mapping.
@export var animation: StringName = &""
## Overrides which frame of that animation is shown. Negative follows the root's frame.
@export var frame: int = -1
