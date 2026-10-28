@tool
extends EditorPlugin


const TIMELINE_SCENE: PackedScene = preload("rig_2d/editor/rig_timeline.tscn")

var _dock: EditorDock
var _timeline: RigTimeline
var _previews: Dictionary[SpriteRig2D, Dictionary] = {}
var _last_rig: SpriteRig2D
var _hide_pending: bool = false


static func _find_rig(node: Node) -> SpriteRig2D:
	var at: Node = node
	while at and at is not SpriteRig2D:
		at = at.get_parent()
	return at as SpriteRig2D


static func _collect_rigs(node: Node, rigs: Array[SpriteRig2D]) -> Array[SpriteRig2D]:
	if node is SpriteRig2D:
		rigs.append(node)
	for child: Node in node.get_children():
		_collect_rigs(child, rigs)
	return rigs


func _enter_tree() -> void:
	_timeline = TIMELINE_SCENE.instantiate()
	_timeline.edits.undo_redo = get_undo_redo()
	_dock = EditorDock.new()
	_dock.title = "Sprite Rig"
	_dock.default_slot = EditorDock.DOCK_SLOT_BOTTOM
	_dock.available_layouts = EditorDock.DOCK_LAYOUT_ALL
	_dock.transient = true
	_dock.add_child(_timeline)
	add_dock(_dock)
	_dock.close()
	scene_changed.connect(_on_scene_changed)


func _exit_tree() -> void:
	scene_changed.disconnect(_on_scene_changed)
	remove_dock(_dock)
	_dock.queue_free()
	RigAnchor.auto_key = false


func _handles(object: Object) -> bool:
	return _rig_of(object) != null


func _edit(object: Object) -> void:
	var rig: SpriteRig2D = _rig_of(object)
	if rig:
		_last_rig = rig
		_timeline.set_rig(rig)


func _make_visible(visible: bool) -> void:
	_hide_pending = not visible
	if visible:
		_dock.open()
		_dock.make_visible()
	else:
		_hide.call_deferred()


func _apply_changes() -> void:
	var root: Node = EditorInterface.get_edited_scene_root()
	if root == null or not _previews.is_empty():
		return
	
	for rig: SpriteRig2D in _collect_rigs(root, []):
		if rig.has_reset():
			_previews[rig] = {
				&"variants": rig.variants.duplicate(),
				&"current_animation": rig.current_animation,
				&"current_frame": rig.current_frame,
			}
			rig.apply_reset()
	if not _previews.is_empty():
		_restore_previews.call_deferred()


func _restore_previews() -> void:
	for rig: SpriteRig2D in _previews:
		if is_instance_valid(rig):
			for property: StringName in _previews[rig]:
				rig.set(property, _previews[rig][property])
	_previews.clear()


func _rig_of(object: Object) -> SpriteRig2D:
	if object is Node:
		return _find_rig(object)
	if not is_instance_valid(_last_rig) or not _last_rig.is_inside_tree():
		return null
	
	var owned: bool = false
	if object is RigClip:
		owned = _last_rig.clips.has(object)
	elif object is RigVariant:
		owned = _last_rig.get_layers().any(
				func(layer: RigLayer) -> bool: return layer.variants.has(object)
		)
	elif object is RigKey:
		for anchor: RigAnchor in _last_rig.get_anchors():
			for list: Array in anchor.keys.values():
				owned = owned or list.has(object)
	return _last_rig if owned else null


func _hide() -> void:
	if not _hide_pending:
		return
	
	_hide_pending = false
	_dock.close()
	_timeline.set_rig(null)


func _on_scene_changed(_root: Node) -> void:
	_dock.close()
	_timeline.set_rig(null)
