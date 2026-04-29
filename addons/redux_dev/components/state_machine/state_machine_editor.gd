@tool
class_name EditorStateMachineEditor
extends Control


const META_KEY := &"sm_resource_path"

@export var current_node_button: Button
@export var select_node_container: CenterContainer
@export var create_state_machine_container: CenterContainer
@export var state_machine_container: MarginContainer
@export var graph: EditorStateMachineGraph

var _current_node: Node = null
var _current_resource: StateMachineResource = null


func _ready() -> void:
	if not _is_plugin_instance():
		return
	
	_show_select_node()


func _on_current_node_button_pressed() -> void:
	EditorInterface.popup_node_selector(_on_node_selected)


func _on_node_selected(node_path: NodePath) -> void:
	if node_path.is_empty():
		return
	
	_current_node = EditorInterface.get_edited_scene_root().get_node(node_path)
	current_node_button.text = _current_node.name
	current_node_button.icon = EditorInterface.get_editor_theme().get_icon(
		_current_node.get_class(), &"EditorIcons"
	)
	
	_evaluate_node(_current_node)


func _evaluate_node(node: Node) -> void:
	if not node.has_meta(META_KEY):
		_show_create()
		return
	
	var path: String = node.get_meta(META_KEY)
	if not ResourceLoader.exists(path):
		_show_create()
		return
	
	_current_resource = load(path)
	graph.load_resource(_current_resource)
	_show_state_machine()


func _on_create_state_machine_pressed() -> void:
	if _current_node == null:
		return
	
	var resource: StateMachineResource = StateMachineResource.new()
	var path: String = _derive_resource_path()
	
	var dir: DirAccess = DirAccess.open(_current_node.scene_file_path.get_base_dir())
	if dir == null:
		return
	
	ResourceSaver.save(resource, path)
	_current_node.set_meta(META_KEY, path)
	_current_resource = resource
	graph.load_resource(_current_resource)
	_show_state_machine()


func _derive_resource_path() -> String:
	var scene_path: String = _current_node.scene_file_path
	var base_dir: String = scene_path.get_base_dir()
	var scene_name: String = scene_path.get_file().get_basename()
	return base_dir.path_join(scene_name + "_sm.tres")


func _show_select_node() -> void:
	select_node_container.show()
	create_state_machine_container.hide()
	state_machine_container.hide()


func _show_create() -> void:
	select_node_container.hide()
	create_state_machine_container.show()
	state_machine_container.hide()


func _show_state_machine() -> void:
	select_node_container.hide()
	create_state_machine_container.hide()
	state_machine_container.show()
	graph.set_target_node(_current_node)


func _is_plugin_instance() -> bool:
	return get_parent() is EditorDock
