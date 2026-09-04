class_name LDViewportGlobalAnchor
extends Control

var _anchored: Dictionary[CanvasItem, Node2D] # [Anchored Item, Substitute]


func _ready() -> void:
	check_group_nodes()


func add(canvas_item: CanvasItem) -> void:
	if canvas_item.get_parent() != self:
		# we create a "substitute" in order to maintain positioning & tree location if removed.
		var substitute: Node2D = Node2D.new()
		_anchored.set(canvas_item, substitute)
		canvas_item.add_sibling(substitute)
		canvas_item.reparent(self)


## Re-seats every anchored item over its substitute. The substitute's position is read in the
## viewport's own canvas space rather than in desktop pixels: this anchor hangs off a plain
## [CanvasLayer], so its children are placed in the project's logical canvas, which the window's
## position and the stretch transform do not belong to.
func refresh() -> void:
	var to_anchor_space: Transform2D = get_canvas_transform().affine_inverse()
	for canvas_item: CanvasItem in _anchored.keys():
		var sub: Node2D = _anchored.get(canvas_item)
		if not is_instance_valid(canvas_item) or not is_instance_valid(sub):
			_anchored.erase(canvas_item)
			continue
		canvas_item.global_position = to_anchor_space * sub.get_global_transform_with_canvas().get_origin()
	
	if get_tree().get_node_count_in_group(&"ld_anchored") > _anchored.size():
		check_group_nodes()


func check_group_nodes() -> void:
	for node: CanvasItem in get_tree().get_nodes_in_group(&"ld_anchored"):
		if node not in _anchored:
			add(node)
