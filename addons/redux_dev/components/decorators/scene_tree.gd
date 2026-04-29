@tool
class_name EditorSceneTreeDecorator
extends RefCounted


const META_KEY: StringName = &"sm_resource_path"
const SM_BUTTON_ID: int = 737

var _tree: Tree = null
var _plugin: EditorPlugin


func _init(plugin: EditorPlugin) -> void:
	_plugin = plugin
	_plugin.get_tree().process_frame.connect(refresh)


func setup() -> bool:
	_tree = _find_scene_tree()
	if _tree == null:
		return false
	
	_tree.button_clicked.connect(_on_tree_button_clicked)
	
	return true



func teardown() -> void:
	if _tree == null:
		return
	
	_tree = null


func refresh() -> void:
	if _tree == null:
		return
	
	_clear_buttons(_tree.get_root())
	_decorate_items(_tree.get_root())


func _find_scene_tree() -> Tree:
	var base: Control = _plugin.get_editor_interface().get_base_control()
	
	var tree: Tree = _find_first_node_by_class(base, "Tree") as Tree
	
	return tree


func _find_first_node_by_class(root_node: Node, target_class: String) -> Node:
	if root_node.get_class() == target_class:
		return root_node
	
	for child: Node in root_node.get_children():
		var found: Node = _find_first_node_by_class(child, target_class)
		if found != null:
			return found
	
	return null


func _decorate_items(item: TreeItem) -> void:
	if item == null:
		return
	
	var node: Node = _get_node_for_item(item)
	if node != null and node.has_meta(META_KEY):
		if not _has_sm_button(item):
			var icon: Texture2D = _plugin.get_editor_interface().get_editor_theme().get_icon(&"AnimationTreeDock", &"EditorIcons")
			item.add_button(0, icon, SM_BUTTON_ID, false, "Open State Machine")
	
	for child: TreeItem in item.get_children():
		_decorate_items(child)


func _has_sm_button(item: TreeItem) -> bool:
	for i: int in range(item.get_button_count(0)):
		if item.get_button_id(0, i) == SM_BUTTON_ID:
			return true
	return false


func _find_sm_button_index(item: TreeItem) -> int:
	for i: int in range(item.get_button_count(0)):
		if item.get_button_id(0, i) == SM_BUTTON_ID:
			return i
	return -1


func _clear_buttons(item: TreeItem) -> void:
	if item == null:
		return
	
	var idx: int = _find_sm_button_index(item)
	if idx != -1:
		item.erase_button(0, idx)
	
	for child: TreeItem in item.get_children():
		_clear_buttons(child)


func _on_tree_button_clicked(item: TreeItem, column: int, id: int, mouse_button_index: int) -> void:
	if id == SM_BUTTON_ID:
		_plugin.make_bottom_panel_item_visible(_plugin.editor)


func _get_node_for_item(item: TreeItem) -> Node:
	var scene_root: Node = _plugin.get_editor_interface().get_edited_scene_root()
	if scene_root == null:
		return null
	
	var node_name: String = item.get_text(0)
	if scene_root.name == node_name:
		return scene_root
	
	return scene_root.find_child(node_name, true, false)
