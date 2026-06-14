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


func refresh() -> void:
	for canvas_item: CanvasItem in _anchored:
		var sub: Node2D = _anchored.get(canvas_item)
		canvas_item.global_position = sub.get_screen_transform().get_origin()
	
	if get_tree().get_node_count_in_group(&"ld_anchored") > _anchored.size():
		check_group_nodes()


func check_group_nodes() -> void:
	for node: Node in get_tree().get_nodes_in_group(&"ld_anchored"):
		if node not in _anchored:
			add(node)
