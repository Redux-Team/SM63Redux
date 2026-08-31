class_name FluddPoseSet
extends Resource


@export var fallback: FluddPose
@export var by_animation: Dictionary[StringName, FluddPose]
@export var by_frame: Dictionary[StringName, Array]


func resolve(animation: StringName, frame: int) -> FluddPose:
	var poses: Array = by_frame.get(animation, [])
	if frame >= 0 and frame < poses.size():
		var pose: FluddPose = poses.get(frame)
		if pose:
			return pose
	
	return by_animation.get(animation, fallback)
