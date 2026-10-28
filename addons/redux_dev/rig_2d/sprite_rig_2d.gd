@tool
class_name SpriteRig2D
extends Node2D


signal animation_finished
signal animation_looped
signal frame_changed

@export var clips: Array[RigClip] = []:
	set(c):
		clips = c
		if is_node_ready():
			refresh()
@export var current_animation: StringName = &"":
	set(a):
		current_animation = a
		_refresh()
@export var current_frame: int = 0:
	set(f):
		if current_frame == f:
			return
		current_frame = f
		frame_changed.emit()
		_refresh()
@export var speed_scale: float = 1.0
@export var autoplay: bool = false
@export var offset: Vector2 = Vector2.ZERO:
	set(o):
		offset = o
		_refresh()
@export var variants: Dictionary[StringName, StringName] = {}:
	set(v):
		variants = v
		_refresh()
@export_group("Flipping")
@export var flip_h: bool = false:
	set(f):
		if lock_flipping:
			return
		flip_h = f
		_apply_flip()
@export var flip_v: bool = false:
	set(f):
		flip_v = f
		_apply_flip()
@export var lock_flipping: bool = false:
	set(l):
		lock_flipping = l
		_sync_processing()
@export var hide_flipping: bool = false:
	set(h):
		hide_flipping = h
		_apply_flip()
@export var velocity_source: CharacterBody2D:
	set(v):
		velocity_source = v
		_sync_processing()
@export_group("Reset", "reset_")
@export var reset_animation: StringName = &""
@export var reset_frame: int = 0
@export var reset_variants: Dictionary[StringName, StringName] = {}

var playing: bool = false:
	set(p):
		playing = p
		if playing:
			_time = 0.0
		_sync_processing()
var looping: bool = true
var local_rotation: float:
	get:
		return -rotation_degrees if flip_h else rotation_degrees
	set(r):
		rotation_degrees = -r if flip_h else r

var _clips: Dictionary[StringName, RigClip] = {}
var _lengths: Dictionary[StringName, int] = {}
var _layers: Array[RigLayer] = []
var _anchors: Array[RigAnchor] = []
var _free: bool = false
var _time: float = 0.0


func _ready() -> void:
	_collect()
	_apply_flip()
	apply_reset()
	if autoplay and not Engine.is_editor_hint():
		play()
	_apply(0.0)


func _process(delta: float) -> void:
	if playing:
		_advance(delta * speed_scale)
	if _free:
		_apply(delta * speed_scale)


func _physics_process(_delta: float) -> void:
	flip_h = velocity_source.velocity.x < 0.0


func _set(property: StringName, value: Variant) -> bool:
	if property == &"self_modulate":
		for layer: RigLayer in _layers:
			layer.self_modulate = value
	return false


func _validate_property(property: Dictionary) -> void:
	if property.name in [&"current_animation", &"reset_animation"]:
		property.hint = PROPERTY_HINT_ENUM_SUGGESTION
		property.hint_string = ",".join(get_clip_names())
	elif property.name == &"current_frame":
		property.hint = PROPERTY_HINT_RANGE
		property.hint_string = "0,%d" % maxi(get_clip_length(current_animation) - 1, 0)


func play(animation: StringName = current_animation) -> void:
	if current_animation == animation and playing:
		return
	current_animation = animation
	current_frame = 0
	playing = true


func play_at_frame(animation: StringName, frame: int) -> void:
	play(animation)
	var clip: RigClip = _clips.get(animation)
	var wrapped: int = posmod(frame, get_clip_length(animation))
	if clip and clip.fps > 0.0:
		_time = float(wrapped) / clip.fps
	current_frame = wrapped


func stop() -> void:
	playing = false


func has_reset() -> bool:
	return not reset_animation.is_empty()


func apply_reset() -> void:
	if not has_reset():
		return
	
	playing = false
	variants = reset_variants.duplicate()
	current_animation = reset_animation
	current_frame = reset_frame


func store_reset() -> void:
	reset_animation = current_animation
	reset_frame = current_frame
	reset_variants = variants.duplicate()


func has_animation(animation: StringName) -> bool:
	return _clips.has(animation)


func get_clip(animation: StringName) -> RigClip:
	return _clips.get(animation)


func get_clip_names() -> PackedStringArray:
	var names: PackedStringArray = []
	for clip: RigClip in clips:
		if clip:
			names.append(clip.name)
	return names


func get_clip_fps(animation: StringName) -> float:
	var clip: RigClip = _clips.get(animation)
	return clip.fps if clip else 0.0


func get_clip_length(animation: StringName) -> int:
	if not _lengths.has(animation):
		var length: int = 1
		for layer: RigLayer in _layers:
			length = maxi(length, layer.get_length(animation))
		_lengths[animation] = length
	return _lengths[animation]


func get_layers() -> Array[RigLayer]:
	return _layers


func get_anchors() -> Array[RigAnchor]:
	return _anchors


func get_variant(axis: StringName) -> StringName:
	return variants.get(axis, &"")


func set_variant(axis: StringName, value: StringName) -> void:
	if get_variant(axis) == value:
		return
	variants[axis] = value
	_refresh()


func refresh() -> void:
	_collect()
	_apply(0.0)


func _collect() -> void:
	_clips.clear()
	_lengths.clear()
	_layers.clear()
	_anchors.clear()
	for clip: RigClip in clips:
		if clip:
			_clips[clip.name] = clip
	_gather(self)
	_free = _layers.any(func(layer: RigLayer) -> bool: return not layer.free_animations.is_empty())
	_sync_processing()


func _gather(node: Node) -> void:
	for child: Node in node.get_children():
		if child is SpriteRig2D:
			continue
		if child is RigLayer:
			_layers.append(child)
		elif child is RigAnchor:
			_anchors.append(child)
		_gather(child)


func _advance(step: float) -> void:
	var clip: RigClip = _clips.get(current_animation)
	if clip == null or clip.fps <= 0.0:
		return
	
	var length: int = get_clip_length(current_animation)
	_time += step
	var next: int = int(_time * clip.fps)
	if next < length:
		current_frame = next
	elif looping and clip.loop:
		_time = fmod(_time, float(length) / clip.fps)
		current_frame = int(_time * clip.fps)
		if not Engine.is_editor_hint():
			animation_looped.emit()
	else:
		current_frame = length - 1
		playing = false
		if not Engine.is_editor_hint():
			animation_finished.emit()


func _apply(step: float) -> void:
	for anchor: RigAnchor in _anchors:
		anchor.pose(current_animation, current_frame, offset)
	for layer: RigLayer in _layers:
		layer.render(self, step)


func _refresh() -> void:
	if is_node_ready():
		_apply(0.0)


func _apply_flip() -> void:
	scale = Vector2(
			absf(scale.x) * (-1.0 if flip_h and not hide_flipping else 1.0),
			absf(scale.y) * (-1.0 if flip_v else 1.0),
	)


func _sync_processing() -> void:
	set_process(playing or _free)
	set_physics_process(
			velocity_source != null and not lock_flipping and not Engine.is_editor_hint()
	)
