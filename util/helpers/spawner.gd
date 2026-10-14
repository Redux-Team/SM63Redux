class_name Spawner


static func spawn_near(source: Node2D, node: Node, offset: Vector2 = Vector2.ZERO, behind: bool = false) -> void:
	var anchor: Node = source
	while anchor and not anchor is GameObject:
		anchor = anchor.get_parent()
	
	var parent: Node2D = (anchor.get_parent() if anchor else source.get_parent()) as Node2D
	if parent == null or not parent.is_inside_tree():
		node.free()
		return
	
	if node is Node2D:
		(node as Node2D).transform = parent.get_global_transform().affine_inverse() * source.get_global_transform().translated(offset)
	parent.add_child.call_deferred(node)
	if behind:
		parent.move_child.call_deferred(node, (anchor if anchor else source).get_index())


static func spawn_burst(source: Node2D, scene: PackedScene, count: int, spread: float) -> void:
	for i: int in count:
		var offset: Vector2 = Vector2(randf_range(-spread, spread), 0.0) if count > 1 else Vector2.ZERO
		spawn_near(source, scene.instantiate(), offset)
