@tool
class_name BackgroundLayerGroup
extends BackgroundLayer


const MAX_DEPTH: int = 8

static var _depth: int = 0
static var _notifying: bool = false

@export_group("Layer Group")
@export var layers: Array[BackgroundLayer]:
	set(l):
		_disconnect_layers()
		layers = l
		_connect_layers()
		emit_changed()
@export var offset: Vector2:
	set(o):
		offset = o
		emit_changed()


func _build() -> Node:
	var group: Node2D = Node2D.new()
	group.position = offset
	group.visible = enabled
	if _depth >= MAX_DEPTH:
		return group
	_depth += 1
	for bg_layer: BackgroundLayer in layers:
		if not bg_layer:
			continue
		var node: Node = bg_layer._build()
		_compose(node)
		group.add_child(node)
	_depth -= 1
	return group


func _update(node: Node, visible_rect: Rect2) -> void:
	var group: Node2D = node as Node2D
	if not group:
		return
	group.position = offset
	var cursor: int = 0
	for bg_layer: BackgroundLayer in layers:
		if not bg_layer:
			continue
		if cursor >= group.get_child_count():
			return
		bg_layer._update(group.get_child(cursor), visible_rect)
		cursor += 1


func _compose(node: Node) -> void:
	for parallax: Parallax2D in collect_parallax(node):
		parallax.scroll_scale *= scroll_rate
		parallax.autoscroll += autoscroll
		parallax.scroll_offset += scroll_offset
		parallax.modulate *= modulate
		if limited:
			parallax.limit_begin = limit.position
			parallax.limit_end = limit.end


static func collect_parallax(node: Node) -> Array[Node]:
	var nodes: Array[Node] = node.find_children("*", "Parallax2D", true, false)
	if node is Parallax2D:
		nodes.append(node)
	return nodes


func _on_layer_changed() -> void:
	if _notifying:
		return
	_notifying = true
	emit_changed()
	_notifying = false


func _connect_layers() -> void:
	for bg_layer: BackgroundLayer in layers:
		if bg_layer and bg_layer != self and not bg_layer.changed.is_connected(_on_layer_changed):
			bg_layer.changed.connect(_on_layer_changed)


func _disconnect_layers() -> void:
	for bg_layer: BackgroundLayer in layers:
		if bg_layer and bg_layer.changed.is_connected(_on_layer_changed):
			bg_layer.changed.disconnect(_on_layer_changed)
