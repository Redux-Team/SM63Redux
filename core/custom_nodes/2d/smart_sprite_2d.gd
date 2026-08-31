@tool
class_name SmartSprite2D
extends Sprite2D


signal animation_finished
signal animation_looped


const FOLLOW_NO_OVERRIDE: StringName = &"(default)"

enum {
	COMPOSITE,
	DIFFUSE,
	NORMAL,
	SHEEN
}


@export_storage var canvas_texture: CanvasTexture
@export_custom(PROPERTY_HINT_ENUM, "Composite,Diffuse,Normal,Sheen") var preview: int = COMPOSITE:
	set(p):
		preview = p
		_update_preview()
@export var lock_flipping: bool = false
@export var flip_with_velocity: bool = true
@export var autoplay: bool = false

## the rotation but it respects whether the sprite is flipped or not
@export var local_rotation: float:
	get:
		return -rotation_degrees if flip_h else rotation_degrees
	set(lr):
		rotation_degrees = -lr if flip_h else lr

@export var rotation_source: Node2D

@export var diffuse_texture: Texture2D:
	set(t):
		diffuse_texture = t
		if canvas_texture:
			canvas_texture.diffuse_texture = t
			_update_preview()
@export var normal_texture: Texture2D:
	set(t):
		normal_texture = t
		if canvas_texture:
			canvas_texture.normal_texture = t
			_update_preview()
@export var sheen_texture: Texture2D:
	set(t):
		sheen_texture = t
		if canvas_texture:
			canvas_texture.specular_texture = t
			_update_preview()

## Subsprites will respect this sprite's flip properties such that the offsets of the subsprites will
## remain consistent with the current sprite as if they were one.
@export var subsprites: Array[SmartSprite2D]
var subsprite_initial_offsets: Dictionary[SmartSprite2D, Vector2]

@export_group("Subsprite", "follow_")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "follow_") var follow_root: bool = false:
	set(f):
		follow_root = f
		if f and follow_origin == Vector2.ZERO:
			follow_origin = position
@export_subgroup("Animation", "follow_")
## Played whenever the root's current animation has no entry in [member follow_overrides].
@export var follow_default: StringName
## Maps a root animation name to the animation this sprite should play instead of the default.
@export var follow_overrides: Dictionary[StringName, StringName]
## Swaps the segment before ":" in the resolved animation name, so one set of overrides can drive
## several variants of the same rig. Falls back to the resolved name when the variant has no such
## animation. Set it at runtime to switch variants, such as between FLUDD nozzles.
@export var follow_variant: StringName:
	set(v):
		follow_variant = v
		_follow_root_sprite()
@export_subgroup("Pose", "follow_")
## The authored base position that recorded poses are applied on top of.
@export var follow_origin: Vector2
@export var follow_poses: Dictionary[StringName, Array]
@export_subgroup("Authoring", "follow_")
## While on, moving this sprite in the editor stores its transform for the root's current frame.
@export var follow_record: bool = false
## Drives the root's animation from here, so a subsprite can be posed without reselecting the root.
## Not stored: it reads and writes the root's current animation directly.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var follow_preview: StringName:
	get:
		var root: SmartSprite2D = get_parent() as SmartSprite2D
		return StringName(root.current_animation) if root else &""
	set(a):
		var root: SmartSprite2D = get_parent() as SmartSprite2D
		if root and not a.is_empty():
			root.current_animation = a
			root.current_frame = root.current_frame
## The animation this sprite plays for the root's current animation. Not stored: it reads and writes
## [member follow_overrides]. Set it to [constant FOLLOW_NO_OVERRIDE] to fall back to the default.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var follow_override: StringName:
	get:
		var root: SmartSprite2D = get_parent() as SmartSprite2D
		if not root:
			return FOLLOW_NO_OVERRIDE
		
		return follow_overrides.get(StringName(root.current_animation), FOLLOW_NO_OVERRIDE)
	set(a):
		var root: SmartSprite2D = get_parent() as SmartSprite2D
		if not root:
			return
		
		if a == FOLLOW_NO_OVERRIDE or a.is_empty():
			follow_overrides.erase(StringName(root.current_animation))
		else:
			follow_overrides.set(StringName(root.current_animation), a)
		_follow_root_sprite()
## Rotation stored for the frame being previewed. Not stored on the node: it reads and writes the pose.
@export_custom(PROPERTY_HINT_RANGE, "-360,360,0.1,degrees", PROPERTY_USAGE_EDITOR) var follow_rotation: float:
	get:
		var pose: SubspritePose = _current_pose()
		return pose.rotation_degrees if pose else 0.0
	set(r):
		var pose: SubspritePose = _editing_pose()
		if pose:
			pose.rotation_degrees = r
			_follow_root_sprite()
## Draws this sprite in front of the root for the frame being previewed.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var follow_in_front: bool:
	get:
		var pose: SubspritePose = _current_pose()
		return pose.in_front if pose else false
	set(f):
		var pose: SubspritePose = _editing_pose()
		if pose:
			pose.in_front = f
			show_behind_parent = not f
## Pins this frame to a specific animation of this sprite, ignoring the per-root-animation mapping.
@export_custom(PROPERTY_HINT_NONE, "", PROPERTY_USAGE_EDITOR) var follow_frame_animation: StringName:
	get:
		var pose: SubspritePose = _current_pose()
		return pose.animation if pose and not pose.animation.is_empty() else FOLLOW_NO_OVERRIDE
	set(a):
		var pose: SubspritePose = _editing_pose()
		if pose:
			pose.animation = &"" if a == FOLLOW_NO_OVERRIDE else a
			_follow_root_sprite()
## Pins this frame to a specific frame of that animation. Negative follows the root's frame.
@export_custom(PROPERTY_HINT_RANGE, "-1,64,1", PROPERTY_USAGE_EDITOR) var follow_frame_index: int:
	get:
		var pose: SubspritePose = _current_pose()
		return pose.frame if pose else -1
	set(f):
		var pose: SubspritePose = _editing_pose()
		if pose:
			pose.frame = f
			_follow_root_sprite()
@export_tool_button("Previous Frame") var _follow_prev: Callable = _step_follow_frame.bind(-1)
@export_tool_button("Next Frame") var _follow_next: Callable = _step_follow_frame.bind(1)
@export_tool_button("Clear Frame Pose") var _follow_clear: Callable = _clear_follow_pose

@export_group("Animated")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "Animated") var animated: bool:
	set(a):
		animated = a
		notify_property_list_changed()
@export var diffuse_frames: SpriteFrames
@export var normal_frames: SpriteFrames
@export var specular_frames: SpriteFrames
@export_subgroup("Animation")
var current_animation: String:
	set(ca):
		current_animation = ca
		notify_property_list_changed()
		apply_frame(current_animation, current_frame)
var current_frame: int:
	set(cf):
		current_frame = cf
		apply_frame(current_animation, current_frame)
		frame_changed.emit()
		queue_redraw()
var speed_scale: float = 1.0
var playing: bool = false:
	set(p):
		playing = p
		notify_property_list_changed()
		if playing:
			_playback_time = 0.0
@export_storage var looping: bool = true:
	set(l):
		looping = l
		notify_property_list_changed()

var _playback_time: float = 0.0
var _follow_applied: Vector2
var _follow_applied_rotation: float
var _follow_neutral: SubspritePose = SubspritePose.new()


func _ready() -> void:
	if autoplay:
		play()
	for subsprite: SmartSprite2D in subsprites:
		subsprite_initial_offsets.set(subsprite, subsprite.position)
	
	_follow_applied = position
	_follow_applied_rotation = rotation_degrees


func get_pose(animation: StringName, frame: int) -> SubspritePose:
	var frames_poses: Array = follow_poses.get(animation, [])
	if frame < 0 or frame >= frames_poses.size():
		return null
	
	return frames_poses.get(frame)


func set_pose(animation: StringName, frame: int, pose: SubspritePose) -> void:
	var frames_poses: Array = follow_poses.get(animation, [])
	while frames_poses.size() <= frame:
		frames_poses.append(null)
	
	frames_poses.set(frame, pose)
	follow_poses.set(animation, frames_poses)


func _follow_root_sprite() -> void:
	var root: SmartSprite2D = get_parent() as SmartSprite2D
	if not follow_root or not root:
		return
	
	var pose: SubspritePose = get_pose(StringName(root.current_animation), root.current_frame)
	var wanted: StringName = follow_overrides.get(StringName(root.current_animation), follow_default)
	if pose and not pose.animation.is_empty():
		wanted = pose.animation
	wanted = _variant_of(wanted)
	if diffuse_frames and diffuse_frames.has_animation(wanted) and current_animation != wanted:
		current_animation = wanted
	
	if diffuse_frames and diffuse_frames.has_animation(current_animation):
		var count: int = diffuse_frames.get_frame_count(current_animation)
		if count > 0:
			var wanted_frame: int = pose.frame if pose and pose.frame >= 0 else root.current_frame
			if current_frame != posmod(wanted_frame, count):
				current_frame = posmod(wanted_frame, count)
	
	if follow_record and Engine.is_editor_hint() and (position != _follow_applied or not is_equal_approx(rotation_degrees, _follow_applied_rotation)):
		_record_pose(root)
		return
	
	_apply_pose(root)


func _variant_of(animation_name: StringName) -> StringName:
	if follow_variant.is_empty() or not diffuse_frames:
		return animation_name
	
	var parts: PackedStringArray = String(animation_name).split(":", true, 1)
	if parts.size() < 2:
		return animation_name
	
	var swapped: StringName = StringName("%s:%s" % [follow_variant, parts.get(1)])
	return swapped if diffuse_frames.has_animation(swapped) else animation_name


func _current_pose() -> SubspritePose:
	var root: SmartSprite2D = get_parent() as SmartSprite2D
	return get_pose(StringName(root.current_animation), root.current_frame) if root else null


func _editing_pose() -> SubspritePose:
	var root: SmartSprite2D = get_parent() as SmartSprite2D
	if not root:
		return null
	
	if not get_pose(StringName(root.current_animation), root.current_frame):
		_record_pose(root)
	
	return get_pose(StringName(root.current_animation), root.current_frame)


func _step_follow_frame(step: int) -> void:
	var root: SmartSprite2D = get_parent() as SmartSprite2D
	if not root or not root.diffuse_frames or not root.diffuse_frames.has_animation(root.current_animation):
		return
	
	var count: int = root.diffuse_frames.get_frame_count(root.current_animation)
	if count > 0:
		root.current_frame = posmod(root.current_frame + step, count)


func _clear_follow_pose() -> void:
	var root: SmartSprite2D = get_parent() as SmartSprite2D
	if root:
		set_pose(StringName(root.current_animation), root.current_frame, null)


func _record_pose(root: SmartSprite2D) -> void:
	var pose: SubspritePose = get_pose(StringName(root.current_animation), root.current_frame)
	if not pose:
		pose = SubspritePose.new()
		set_pose(StringName(root.current_animation), root.current_frame, pose)
	
	var mirror: float = -1.0 if root.flip_h else 1.0
	pose.offset = Vector2((position.x * mirror) - follow_origin.x, position.y - follow_origin.y)
	pose.rotation_degrees = rotation_degrees * mirror
	pose.visible = visible
	pose.in_front = not show_behind_parent
	_follow_applied = position
	_follow_applied_rotation = rotation_degrees


func _apply_pose(root: SmartSprite2D) -> void:
	var pose: SubspritePose = get_pose(StringName(root.current_animation), root.current_frame)
	if not pose:
		pose = _follow_neutral
	
	var mirror: float = -1.0 if root.flip_h else 1.0
	visible = pose.visible
	show_behind_parent = not pose.in_front
	rotation_degrees = pose.rotation_degrees * mirror
	position = Vector2((follow_origin.x + pose.offset.x) * mirror, follow_origin.y + pose.offset.y)
	_follow_applied = position
	_follow_applied_rotation = rotation_degrees


func _notification(what: int) -> void:
	if what == NOTIFICATION_POST_ENTER_TREE:
		if not canvas_texture:
			canvas_texture = CanvasTexture.new()
		texture = canvas_texture


func _set(property: StringName, value: Variant) -> bool:
	# Subsprite horizontal handling
	if property == "flip_h":
		for subsprite: SmartSprite2D in subsprites:
			subsprite.flip_h = value
			if subsprite.follow_root:
				continue
			var original_offset: Vector2 = subsprite_initial_offsets.get(subsprite)
			
			subsprite.position.x = original_offset.x * (-1 if value else 1)
	# Subsprite vertical handling 
	if property == "flip_v":
		for subsprite: SmartSprite2D in subsprites:
			subsprite.flip_v = value
			if subsprite.follow_root:
				continue
			var original_offset: Vector2 = subsprite_initial_offsets.get(subsprite)
			
			subsprite.position.y = original_offset.y * (-1 if value else 1)
		return true
	
	# Subsprite speed scale
	if property == "speed_scale":
		for subsprite: SmartSprite2D in subsprites:
			subsprite.speed_scale = value
		return true
	
	return property == "flip_h" and lock_flipping


func _process(delta: float) -> void:
	if follow_root:
		_follow_root_sprite()
	if not diffuse_frames or not playing:
		return
	if current_animation == "" or not diffuse_frames.has_animation(current_animation):
		return
	
	var fps: float = diffuse_frames.get_animation_speed(current_animation)
	var frame_count: int = diffuse_frames.get_frame_count(current_animation)
	
	if fps <= 0.0 or frame_count == 0:
		return
	
	_playback_time += delta * speed_scale
	
	var new_frame: int = int(_playback_time * fps)
	
	if new_frame >= frame_count:
		if looping and diffuse_frames.get_animation_loop(current_animation):
			_playback_time = fmod(_playback_time, float(frame_count) / fps)
			current_frame = int(_playback_time * fps)
			if not Engine.is_editor_hint():
				animation_looped.emit()
		else:
			current_frame = frame_count - 1
			playing = false
			if not Engine.is_editor_hint():
				animation_finished.emit()
	else:
		current_frame = new_frame


func _physics_process(_delta: float) -> void:
	if flip_with_velocity and rotation_source and rotation_source is Entity and not lock_flipping:
		flip_h = rotation_source.velocity.x < 0


func play(animation_name: StringName = current_animation) -> void:
	if current_animation == animation_name and playing:
		return
	current_animation = animation_name
	_playback_time = 0.0
	current_frame = 0
	region_enabled = true
	playing = true


func play_at_frame(animation_name: StringName, frame: int) -> void:
	play(animation_name)
	if not diffuse_frames or not diffuse_frames.has_animation(animation_name):
		return
	
	var count: int = diffuse_frames.get_frame_count(animation_name)
	if count <= 0:
		return
	
	var wrapped: int = posmod(frame, count)
	var fps: float = diffuse_frames.get_animation_speed(animation_name)
	if fps > 0.0:
		_playback_time = float(wrapped) / fps
	current_frame = wrapped


func stop() -> void:
	playing = false


func has_animation(animation_name: StringName) -> bool:
	return diffuse_frames != null and diffuse_frames.has_animation(animation_name)


func _get_property_list() -> Array[Dictionary]:
	var property_list: Array[Dictionary] = []
	var animation_names: PackedStringArray = diffuse_frames.get_animation_names() if diffuse_frames else PackedStringArray()
	var frame_count: int = diffuse_frames.get_frame_count(current_animation) - 1 if diffuse_frames and current_animation != "" else 0
	var locked_usage: int = PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
	var normal_usage: int = PROPERTY_USAGE_DEFAULT
	
	property_list.append({
		"name": "current_animation",
		"type": TYPE_STRING,
		"hint": PROPERTY_HINT_ENUM,
		"hint_string": ",".join(animation_names),
		"usage": locked_usage if playing else normal_usage
	})
	property_list.append({
		"name": "current_frame",
		"type": TYPE_INT,
		"hint": PROPERTY_HINT_RANGE,
		"hint_string": "0,%d" % frame_count,
		"usage": locked_usage if playing else normal_usage
	})
	property_list.append({
		"name": "speed_scale",
		"type": TYPE_FLOAT,
	})
	property_list.append({
		"name": "playing",
		"type": TYPE_BOOL
	})
	property_list.append({
		"name": "looping",
		"type": TYPE_BOOL
	})
	
	return property_list


func _validate_property(property: Dictionary) -> void:
	if property.get("name") in [
		"texture", "region_rect", "region_enabled", "region_filter_clip_enabled",
		"hframes", "vframes", "frame", "frame_coords"
	]: property.set("usage", PROPERTY_USAGE_NO_EDITOR)
	elif property.get("name") in ["diffuse_texture", "normal_texture", "sheen_texture"]:
		if animated: property.set("usage", PROPERTY_USAGE_NO_EDITOR)
	elif property.get("name") == "follow_preview":
		var root: SmartSprite2D = get_parent() as SmartSprite2D
		if root and root.diffuse_frames:
			property.set("hint", PROPERTY_HINT_ENUM)
			property.set("hint_string", ",".join(root.diffuse_frames.get_animation_names()))
	elif property.get("name") == "follow_default" and diffuse_frames:
		property.set("hint", PROPERTY_HINT_ENUM)
		property.set("hint_string", ",".join(diffuse_frames.get_animation_names()))
	elif property.get("name") == "follow_frame_animation" and diffuse_frames:
		property.set("hint", PROPERTY_HINT_ENUM)
		property.set("hint_string", ",".join([FOLLOW_NO_OVERRIDE] + Array(diffuse_frames.get_animation_names())))
	elif property.get("name") == "follow_override" and diffuse_frames:
		property.set("hint", PROPERTY_HINT_ENUM)
		property.set("hint_string", ",".join([FOLLOW_NO_OVERRIDE] + Array(diffuse_frames.get_animation_names())))


func _update_preview() -> void:
	if not canvas_texture:
		return
	texture = null
	match preview:
		COMPOSITE: 
			texture = canvas_texture
			var diff: Texture2D = canvas_texture.diffuse_texture
			if diff and diff is not CompressedTexture2D:
				# BUG this is an issue with godot where re-assigning the texture
				# to a CanvasTexture does not update unless a region is set.
				region_enabled = true
				region_rect = diff.region
		DIFFUSE: texture = canvas_texture.diffuse_texture
		NORMAL: texture = canvas_texture.normal_texture
		SHEEN: texture = canvas_texture.specular_texture


func apply_frame(animation_name: StringName, animation_frame: int) -> void:
	var all_frames: Array[SpriteFrames] = [diffuse_frames, normal_frames, specular_frames]
	var new_canvas: CanvasTexture = CanvasTexture.new()
	new_canvas.diffuse_texture = canvas_texture.diffuse_texture
	new_canvas.normal_texture = canvas_texture.normal_texture
	new_canvas.specular_texture = canvas_texture.specular_texture
	
	for i: int in 3:
		var frames: SpriteFrames = all_frames[i]
		if not frames or not frames.has_animation(animation_name):
			continue
		if frames.get_frame_count(animation_name) <= animation_frame:
			continue
		var tex: Texture2D = frames.get_frame_texture(animation_name, animation_frame)
		match i:
			0: new_canvas.diffuse_texture = tex
			1: new_canvas.normal_texture = tex
			2: new_canvas.specular_texture = tex
	
	canvas_texture = new_canvas
	texture = canvas_texture
	_update_preview()
