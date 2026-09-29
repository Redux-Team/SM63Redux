@tool
class_name TiltHBoxContainer extends HBoxContainer

## Slope (y / x). 0 is perfectly horizontal.
## Note: positive y is downwards.
@export var slope: float = 0:
	set(new_slope):
		slope = new_slope
		queue_sort()

func _notification(what: int) -> void:
	# This is always run after HBoxContainer sort.
	if (what == NOTIFICATION_SORT_CHILDREN):
		if slope == 0.0:
			pass # do nothing
		else:
			var children: Array[Node] = get_children()
			var control_children: Array[Control] = []
			for node: Node in children:
				if node is Control:
					control_children.append(node)
			
			if slope > 0.0:
				_offset_children(control_children, slope)
			elif slope < 0.0:
				control_children.reverse()
				_offset_children(control_children, -slope)

func _offset_children(controls: Array[Control], offset_slope: float) -> void:
	var running_offset: float = 0
	
	# Offset the first control to keep it in the corner after the for loop offsets are applied
	running_offset -= controls[0].size.x / 2
	# Offset each control to have them follow the slope
	for node: Control in controls:
		running_offset += node.size.x / 2
		node.position.y += running_offset * offset_slope
		running_offset += node.size.x / 2
		running_offset += get_theme_constant("separation")
	# Offset the last control to keep it in the corner after the for loop offsets are applied
	running_offset -= controls[-1].size.x / 2
	running_offset -= get_theme_constant("separation")
	
	for node: Control in controls:
		node.size.y -= running_offset * offset_slope
