class_name DoublyLinkedList
extends RefCounted


## Whether the first and last node are connected
var circular: bool = true
# The first node assigned to the list
var _head: ListNode = ListNode.new()


func _init() -> void:
	_head = ListNode.new()
	_head._previous_node = _head
	_head._next_node = _head
	_head._list = self


## Returns the first node assigned to the list.
func get_head() -> ListNode:
	return _head


func get_size() -> int:
	var count: int = 0
	var current_node: ListNode = get_head()
	
	while true:
		current_node = current_node.get_next()
		count += 1
		if current_node == get_head():
			break
	
	return count


func print_list() -> void:
	var current_node: ListNode = get_head()
	var output: String = "%s" % current_node
	
	while true:
		current_node = current_node.get_next()
		if current_node == get_head():
			break
		output += " <-> %s" % current_node
	
	print(output)


class ListNode:
	var _next_node: ListNode
	var _previous_node: ListNode
	var _list: DoublyLinkedList
	var _data: Variant
	
	
	func advance(amount: int = 1) -> ListNode:
		assert(amount >= 0)
		var current_node: ListNode
		for i: int in amount:
			current_node = get_next()
		return current_node
	
	
	func get_next() -> ListNode:
		return _next_node
	
	
	func get_previous() -> ListNode:
		return _previous_node
	
	
	func delete() -> void:
		_previous_node._next_node = _next_node
		_next_node._previous_node = _previous_node
		free()
	
	
	func create_next(node_data: Variant = null) -> ListNode:
		var node: ListNode = ListNode.new()
		node._next_node = _next_node
		node._previous_node = self
		node._list = _list
		_next_node._previous_node = node
		_next_node = node
		if node_data:
			node._data = node_data
		return node
	
	
	func create_previous(node_data: Variant = null) -> ListNode:
		var node: ListNode = ListNode.new()
		node._previous_node = _previous_node
		node._next_node = self
		node._list = _list
		_previous_node._next_node = node
		_previous_node = node
		if node_data:
			node._data = node_data
		return node
