class_name Teardown

const FRAME_BUDGET_USEC: int = 4000
const UNIT_SIZE: int = 32


static func free_nodes(nodes: Array, tree: SceneTree) -> void:
	var start: int = Time.get_ticks_usec()
	for i: int in nodes.size():
		if is_instance_valid(nodes.get(i)):
			(nodes.get(i) as Node).free()
		if Time.get_ticks_usec() - start > FRAME_BUDGET_USEC:
			await tree.process_frame
			start = Time.get_ticks_usec()


static func free_descendants(root: Node) -> void:
	var nodes: Array[Node] = []
	_collect_units(root, nodes)
	await free_nodes(nodes, root.get_tree())


static func _collect_units(node: Node, into: Array[Node]) -> void:
	var children: Array[Node] = node.get_children()
	children.reverse()
	for child: Node in children:
		if child.find_children("*", "", true, false).size() > UNIT_SIZE:
			_collect_units(child, into)
		into.append(child)
