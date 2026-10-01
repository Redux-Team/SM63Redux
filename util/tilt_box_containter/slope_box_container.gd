@tool
## A container that arranges its child controls horizontally or vertically
## in a slanted manner, determined by [member slope].
class_name SlopeBoxContainer extends BoxContainer

## Slope. Represents y/x when horizontal, and x/y when vertical.
## A slope of 0 keeps this unchanged from an ordinary [BoxContainer]
## Note: positive y is downwards.
@export var slope: float = 0.0:
	set(new_slope):
		slope = new_slope
		queue_sort()



func _notification(what: int) -> void:
	# This is always run after BoxContainer sort.
	if (what == NOTIFICATION_SORT_CHILDREN):
		# Offsets are only done when slope is not 0.
		if slope != 0.0:
			var control_children: Array[Control] = []
			for node: Node in get_children():
				if node is Control:
					control_children.append(node)
			
			if slope > 0.0:
				_offset_children(control_children, slope)
			else:
				control_children.reverse()
				_offset_children(control_children, -slope)



func _offset_children(controls: Array[Control], offset_slope: float) -> void:
	# Used to swap x and y when vertical
	var v: int = int(vertical)
	
	var running_offset: float = 0
	
	# Offset the first control to keep it in the corner after the for-loop offsets are applied
	running_offset -= controls[0].size[0^v] / 2
	# Offset each control to have them follow the slope
	for node: Control in controls:
		running_offset += node.size[0^v] / 2
		node.position[1^v] += running_offset * offset_slope
		running_offset += node.size[0^v] / 2
		running_offset += get_theme_constant("separation")
	# Offset the last control to keep it in the corner after the for-loop offsets are applied
	running_offset -= controls[-1].size[0^v] / 2
	running_offset -= get_theme_constant("separation")
	
	# Resize all nodes to fit it within the rect after the offsets
	for node: Control in controls:
		node.size[1^v] -= running_offset * offset_slope
