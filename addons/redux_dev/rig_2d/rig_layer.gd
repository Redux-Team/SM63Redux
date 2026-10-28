@tool
class_name RigLayer
extends Sprite2D


@export var frames: SpriteFrames
@export var anchor: RigAnchor
@export var default_animation: StringName = &""
@export var aliases: Dictionary[StringName, StringName] = {}
@export var free_animations: Array[StringName] = []
@export var visible_when: Dictionary[StringName, StringName] = {}
@export var variants: Array[RigVariant] = []

var _free_time: float = 0.0
var _followed: bool = false
var _followed_at: Transform2D = Transform2D.IDENTITY


func _init() -> void:
	use_parent_material = true


func is_animated() -> bool:
	return frames != null or not variants.is_empty()


func get_length(animation: StringName) -> int:
	var length: int = frames.get_frame_count(animation) if has_own(animation) else 0
	for variant: RigVariant in variants:
		if variant and variant.frames and variant.frames.has_animation(animation):
			length = maxi(length, variant.frames.get_frame_count(animation))
	return length


func has_own(animation: StringName) -> bool:
	return frames != null and frames.has_animation(animation)


func is_shown(rig: SpriteRig2D) -> bool:
	for axis: StringName in visible_when:
		var wanted: StringName = visible_when[axis]
		var current: StringName = rig.get_variant(axis)
		if current.is_empty() or (not wanted.is_empty() and current != wanted):
			return false
	return true


func resolve(clip: StringName) -> StringName:
	return aliases.get(clip, clip if default_animation.is_empty() else default_animation)


func render(rig: SpriteRig2D, step: float) -> void:
	if anchor:
		if Engine.is_editor_hint() and _followed and transform != _followed_at:
			anchor.global_transform = global_transform
		global_transform = anchor.global_transform
		_followed_at = transform
		_followed = true
		var order: int = get_index() + anchor.z * get_parent().get_child_count()
		RenderingServer.canvas_item_set_draw_index(get_canvas_item(), order)
	else:
		offset = rig.offset
	if not is_animated():
		return
	
	var animation: StringName = resolve(rig.current_animation)
	var source: SpriteFrames = _source(rig, animation)
	if source == null:
		texture = null
		return
	
	var count: int = source.get_frame_count(animation)
	var index: int = posmod(rig.current_frame, count)
	if free_animations.has(animation):
		_free_time += step
		index = int(_free_time * source.get_animation_speed(animation)) % count
	_show(source.get_frame_texture(animation, index))


func _source(rig: SpriteRig2D, animation: StringName) -> SpriteFrames:
	if not is_shown(rig):
		return null
	
	for variant: RigVariant in variants:
		if variant and variant.provides(rig, animation):
			return variant.frames
	return frames if has_own(animation) else null


func _show(frame_texture: Texture2D) -> void:
	var atlas: AtlasTexture = frame_texture as AtlasTexture
	region_enabled = atlas != null
	if atlas:
		region_rect = atlas.region
	texture = atlas.atlas if atlas else frame_texture
