class_name EditorSession
extends RefCounted

var level: LevelData
var area_uuid: StringName
var _held: Node


func is_held() -> bool:
	return is_instance_valid(_held)


func suspend_into(tree: SceneTree, scene: PackedScene) -> void:
	var editor: Node = tree.current_scene
	discard()
	if editor.has_method(&"set_suspended"):
		editor.call(&"set_suspended", true)
	else:
		tree.root.remove_child(editor)
	_held = editor
	
	var next: Node = scene.instantiate()
	tree.root.add_child(next)
	tree.current_scene = next


func resume(tree: SceneTree) -> bool:
	if not is_instance_valid(_held):
		_held = null
		return false
	
	var editor: Node = _held
	var outgoing: Node = tree.current_scene
	_held = null
	level = null
	if not editor.is_inside_tree():
		tree.root.add_child(editor)
	if editor.has_method(&"set_suspended"):
		editor.call(&"set_suspended", false)
	tree.current_scene = editor
	if is_instance_valid(outgoing) and outgoing != editor:
		outgoing.queue_free()
	
	return true


func resume_or_open(tree: SceneTree, scene_path: String) -> void:
	if not resume(tree):
		tree.change_scene_to_file(scene_path)


func discard() -> void:
	if is_instance_valid(_held):
		_held.free()
	_held = null
