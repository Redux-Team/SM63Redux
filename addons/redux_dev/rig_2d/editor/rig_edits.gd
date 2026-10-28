@tool
class_name RigEdits
extends Node


const CAPTURE_ACTIONS: PackedStringArray = [
	"Auto Key Rig Anchor",
	"Offset Rig Anchor in Clip",
	"Offset Rig Anchor in All Clips",
]

var undo_redo: EditorUndoRedoManager
var rig: SpriteRig2D


static func textures_of(frames: SpriteFrames, animation: StringName) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	if frames and frames.has_animation(animation):
		for i: int in frames.get_frame_count(animation):
			textures.append(frames.get_frame_texture(animation, i))
	return textures


static func _frames_of(layer: RigLayer) -> Array[SpriteFrames]:
	var all: Array[SpriteFrames] = []
	if layer.frames:
		all.append(layer.frames)
	for variant: RigVariant in layer.variants:
		if variant and variant.frames:
			all.append(variant.frames)
	return all


static func _frame_size(frames: SpriteFrames, texture: Texture2D) -> Vector2:
	for animation: StringName in frames.get_animation_names():
		if frames.get_frame_count(animation) > 0 and frames.get_frame_texture(animation, 0):
			return frames.get_frame_texture(animation, 0).get_size()
	return Vector2(texture.get_height(), texture.get_height())


static func _slice(texture: Texture2D, frame_size: Vector2) -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var columns: int = maxi(int(texture.get_width() / frame_size.x), 1)
	var rows: int = maxi(int(texture.get_height() / frame_size.y), 1)
	for y: int in rows:
		for x: int in columns:
			var atlas: AtlasTexture = AtlasTexture.new()
			atlas.atlas = texture
			atlas.region = Rect2(Vector2(x, y) * frame_size, frame_size)
			textures.append(atlas)
	return textures


func add_clip() -> void:
	var clip: RigClip = rig.get_clip(rig.current_animation)
	var created: RigClip = RigClip.new()
	created.name = _unique_clip_name("clip")
	if clip:
		created.fps = clip.fps
	var list: Array[RigClip] = rig.clips.duplicate()
	list.insert(list.find(clip) + 1, created)
	_begin("Add Rig Clip")
	_change(rig, &"clips", list)
	_change(rig, &"current_animation", created.name)
	_commit()


func duplicate_clip() -> void:
	var clip: RigClip = rig.get_clip(rig.current_animation)
	if clip == null:
		return
	
	var copy: RigClip = clip.duplicate()
	copy.name = _unique_clip_name("%s_copy" % clip.name)
	var list: Array[RigClip] = rig.clips.duplicate()
	list.insert(list.find(clip) + 1, copy)
	_begin("Duplicate Rig Clip")
	undo_redo.add_do_method(self, &"_copy_clip_data", rig, clip.name, copy.name, false)
	undo_redo.add_undo_method(self, &"_copy_clip_data", rig, copy.name, &"", true)
	_change(rig, &"clips", list)
	_change(rig, &"current_animation", copy.name)
	_commit()


func delete_clip() -> void:
	var clip: RigClip = rig.get_clip(rig.current_animation)
	if clip == null:
		return
	
	var list: Array[RigClip] = rig.clips.duplicate()
	list.erase(clip)
	_begin("Delete Rig Clip")
	_change(rig, &"clips", list)
	_change(rig, &"current_animation", &"" if list.is_empty() else list[0].name)
	if rig.reset_animation == clip.name:
		_change(rig, &"reset_animation", &"")
	_commit()


func move_clip(direction: int) -> void:
	var list: Array[RigClip] = rig.clips.duplicate()
	var index: int = list.find(rig.get_clip(rig.current_animation))
	var target: int = index + direction
	if index < 0 or target < 0 or target >= list.size():
		return
	
	list.insert(target, list.pop_at(index))
	_begin("Reorder Rig Clip")
	_change(rig, &"clips", list)
	_commit()


func rename_clip(new_name: StringName) -> void:
	var old_name: StringName = rig.current_animation
	if new_name.is_empty() or new_name == old_name or rig.has_animation(new_name):
		return
	if rig.get_clip(old_name) == null:
		return
	
	_begin("Rename Rig Clip")
	undo_redo.add_do_method(self, &"_rename_clip", rig, old_name, new_name)
	undo_redo.add_undo_method(self, &"_rename_clip", rig, new_name, old_name)
	_commit()


func set_clip_property(property: StringName, value: Variant) -> void:
	var clip: RigClip = rig.get_clip(rig.current_animation) if is_instance_valid(rig) else null
	if clip == null or clip.get(property) == value:
		return
	
	_begin("Set Rig Clip %s" % property.capitalize(), UndoRedo.MERGE_ENDS)
	_change(clip, property, value)
	_commit()


func store_reset(store: bool) -> void:
	var stored: Dictionary[StringName, StringName] = {}
	if store:
		stored = rig.variants.duplicate()
	_begin("Store Rig Reset" if store else "Clear Rig Reset")
	_change(rig, &"reset_animation", rig.current_animation if store else &"")
	_change(rig, &"reset_frame", rig.current_frame if store else 0)
	_change(rig, &"reset_variants", stored)
	_commit()


func reset() -> void:
	_begin("Reset Rig")
	undo_redo.add_do_method(rig, &"apply_reset")
	undo_redo.add_undo_property(rig, &"variants", rig.variants.duplicate())
	undo_redo.add_undo_property(rig, &"current_animation", rig.current_animation)
	undo_redo.add_undo_property(rig, &"current_frame", rig.current_frame)
	_commit()


func set_variant(axis: StringName, value: StringName) -> void:
	var variants: Dictionary[StringName, StringName] = rig.variants.duplicate()
	variants[axis] = value
	_begin("Preview Rig Variant")
	_change(rig, &"variants", variants)
	_commit()


func add_node(anchor: bool) -> void:
	var node: Node2D = RigAnchor.new() if anchor else RigLayer.new()
	node.name = "Anchor" if anchor else "Layer"
	node.set_meta(&"_custom_type_script", ResourceUID.path_to_uid(node.get_script().resource_path))
	var selection: EditorSelection = EditorInterface.get_selection()
	_begin("Add Rig %s" % node.name)
	undo_redo.add_do_method(rig, &"add_child", node, true)
	undo_redo.add_do_property(node, &"owner", EditorInterface.get_edited_scene_root())
	undo_redo.add_do_method(selection, &"clear")
	undo_redo.add_do_method(selection, &"add_node", node)
	undo_redo.add_do_reference(node)
	undo_redo.add_undo_method(selection, &"remove_node", node)
	undo_redo.add_undo_method(selection, &"add_node", rig)
	undo_redo.add_undo_method(rig, &"remove_child", node)
	_commit()


func move_node(node: Node, index: int) -> void:
	_begin("Reorder Rig Node")
	undo_redo.add_do_method(node.get_parent(), &"move_child", node, index)
	undo_redo.add_undo_method(node.get_parent(), &"move_child", node, node.get_index())
	_commit()


func toggle_visible(item: CanvasItem) -> void:
	_begin("Toggle Rig Node Visibility")
	_change(item, &"visible", not item.visible)
	_commit()


func toggle_interpolation(anchor: RigAnchor) -> void:
	_begin("Toggle Rig Anchor Blending")
	_change(anchor, &"interpolate", not anchor.interpolate)
	_commit()


func key(anchor: RigAnchor, frame: int) -> void:
	var before: Dictionary[StringName, Array] = anchor.duplicate_keys()
	anchor.set_key(rig.current_animation, anchor.make_key(frame, rig.offset))
	_commit_keys(anchor, "Key Rig Anchor", before)


func clear_key(anchor: RigAnchor, frame: int) -> void:
	if anchor.get_key(rig.current_animation, frame) == null:
		return
	
	var before: Dictionary[StringName, Array] = anchor.duplicate_keys()
	anchor.remove_key(rig.current_animation, frame)
	_commit_keys(anchor, "Clear Rig Anchor Key", before)


func clear_clip_keys(anchor: RigAnchor) -> void:
	var before: Dictionary[StringName, Array] = anchor.duplicate_keys()
	anchor.keys.erase(rig.current_animation)
	_commit_keys(anchor, "Clear Rig Anchor Keys", before)


func move_key(anchor: RigAnchor, from: int, to: int) -> void:
	var key_at: RigKey = anchor.get_key(rig.current_animation, from)
	if key_at == null:
		return
	
	var before: Dictionary[StringName, Array] = anchor.duplicate_keys()
	var moved: RigKey = key_at.duplicate()
	moved.frame = to
	anchor.remove_key(rig.current_animation, from)
	anchor.set_key(rig.current_animation, moved)
	_commit_keys(anchor, "Move Rig Key", before)


func capture(before: Dictionary[StringName, Variant], anchor: RigAnchor) -> void:
	_begin(CAPTURE_ACTIONS[RigAnchor.key_scope])
	for property: StringName in before:
		var after: Variant = anchor.get(property)
		if property == &"keys":
			after = anchor.duplicate_keys()
		undo_redo.add_do_property(anchor, property, after)
		undo_redo.add_undo_property(anchor, property, before[property])
	_commit(false)


func drop_strip(
		target: Object,
		frames: SpriteFrames,
		animation: StringName,
		texture: Texture2D,
) -> void:
	_begin("Set Rig Strip")
	if frames == null:
		frames = SpriteFrames.new()
		frames.remove_animation(&"default")
		_change(target, &"frames", frames)
	_change_strip(frames, animation, _slice(texture, _frame_size(frames, texture)))
	_commit()


func move_frame(frames: SpriteFrames, animation: StringName, from: int, to: int) -> void:
	var textures: Array[Texture2D] = textures_of(frames, animation)
	if from >= textures.size():
		return
	
	var texture: Texture2D = textures.pop_at(from)
	textures.insert(mini(to, textures.size()), texture)
	_begin("Move Rig Frame")
	_change_strip(frames, animation, textures)
	_commit()


func edit_frame(frames: SpriteFrames, animation: StringName, frame: int, copy: bool) -> void:
	var textures: Array[Texture2D] = textures_of(frames, animation)
	var at: int = posmod(frame, textures.size())
	if copy:
		textures.insert(at, textures[at])
	else:
		textures.remove_at(at)
	_begin("Duplicate Rig Frame" if copy else "Delete Rig Frame")
	_change_strip(frames, animation, textures)
	_commit()


func clear_strip(frames: SpriteFrames, animation: StringName) -> void:
	_begin("Clear Rig Strip")
	_change_strip(frames, animation, [] as Array[Texture2D])
	_commit()


func add_variant(layer: RigLayer) -> RigVariant:
	var variant: RigVariant = RigVariant.new()
	variant.axis = &"variant"
	variant.value = &"on"
	variant.frames = SpriteFrames.new()
	variant.frames.remove_animation(&"default")
	var list: Array[RigVariant] = layer.variants.duplicate()
	list.append(variant)
	_begin("Add Rig Variant")
	_change(layer, &"variants", list)
	_commit()
	return variant


func remove_variant(layer: RigLayer, index: int) -> void:
	var list: Array[RigVariant] = layer.variants.duplicate()
	list.remove_at(index)
	_begin("Remove Rig Variant")
	_change(layer, &"variants", list)
	_commit()


func move_variant(layer: RigLayer, from: int, to: int) -> void:
	var list: Array[RigVariant] = layer.variants.duplicate()
	list.insert(to, list.pop_at(from))
	_begin("Reorder Rig Variant")
	_change(layer, &"variants", list)
	_commit()


func edit_variant(variant: RigVariant, axis: StringName, value: StringName) -> void:
	_begin("Edit Rig Variant")
	_change(variant, &"axis", axis)
	_change(variant, &"value", value)
	_commit()


func _begin(action: String, merge: UndoRedo.MergeMode = UndoRedo.MERGE_DISABLE) -> void:
	undo_redo.create_action(action, merge, rig)


func _change(object: Object, property: StringName, value: Variant) -> void:
	undo_redo.add_do_property(object, property, value)
	undo_redo.add_undo_property(object, property, object.get(property))


func _commit(execute: bool = true) -> void:
	undo_redo.add_do_method(rig, &"refresh")
	undo_redo.add_undo_method(rig, &"refresh")
	undo_redo.commit_action(execute)


func _commit_keys(anchor: RigAnchor, action: String, before: Dictionary[StringName, Array]) -> void:
	_begin(action)
	undo_redo.add_do_property(anchor, &"keys", anchor.duplicate_keys())
	undo_redo.add_undo_property(anchor, &"keys", before)
	_commit()


func _change_strip(frames: SpriteFrames, animation: StringName, textures: Array[Texture2D]) -> void:
	var clip: RigClip = rig.get_clip(rig.current_animation)
	var fps: float = clip.fps if clip else 5.0
	var loop: bool = clip.loop if clip else true
	var before: Array[Texture2D] = textures_of(frames, animation)
	undo_redo.add_do_method(self, &"_write_animation", frames, animation, textures, fps, loop)
	undo_redo.add_undo_method(self, &"_write_animation", frames, animation, before, fps, loop)


func _write_animation(
		frames: SpriteFrames,
		animation: StringName,
		textures: Array[Texture2D],
		fps: float,
		loop: bool,
) -> void:
	if frames.has_animation(animation):
		frames.remove_animation(animation)
	if not textures.is_empty():
		frames.add_animation(animation)
		frames.set_animation_speed(animation, fps)
		frames.set_animation_loop(animation, loop)
		for texture: Texture2D in textures:
			frames.add_frame(animation, texture)
	frames.emit_changed()


func _rename_clip(target: SpriteRig2D, old_name: StringName, new_name: StringName) -> void:
	target.get_clip(old_name).name = new_name
	for layer: RigLayer in target.get_layers():
		for frames: SpriteFrames in _frames_of(layer):
			if frames.has_animation(old_name) and not frames.has_animation(new_name):
				frames.rename_animation(old_name, new_name)
		var aliases: Dictionary[StringName, StringName] = {}
		for clip: StringName in layer.aliases:
			var animation: StringName = layer.aliases[clip]
			aliases[new_name if clip == old_name else clip] = \
					new_name if animation == old_name else animation
		layer.aliases = aliases
		if layer.default_animation == old_name:
			layer.default_animation = new_name
		var free: Array[StringName] = []
		for animation: StringName in layer.free_animations:
			free.append(new_name if animation == old_name else animation)
		layer.free_animations = free
	for anchor: RigAnchor in target.get_anchors():
		if anchor.keys.has(old_name):
			anchor.keys[new_name] = anchor.keys[old_name]
			anchor.keys.erase(old_name)
	if target.reset_animation == old_name:
		target.reset_animation = new_name
	target.current_animation = new_name


func _copy_clip_data(target: SpriteRig2D, from: StringName, to: StringName, remove: bool) -> void:
	for layer: RigLayer in target.get_layers():
		for frames: SpriteFrames in _frames_of(layer):
			if remove and frames.has_animation(from):
				frames.remove_animation(from)
			elif not remove and frames.has_animation(from) and not frames.has_animation(to):
				frames.duplicate_animation(from, to)
	for anchor: RigAnchor in target.get_anchors():
		if remove:
			anchor.keys.erase(from)
		elif anchor.keys.has(from):
			anchor.keys[to] = anchor.keys[from].map(
					func(key_at: RigKey) -> RigKey: return key_at.duplicate()
			)


func _unique_clip_name(base: String) -> StringName:
	var candidate: String = base
	var suffix: int = 2
	while rig.has_animation(StringName(candidate)):
		candidate = "%s_%d" % [base, suffix]
		suffix += 1
	return StringName(candidate)
