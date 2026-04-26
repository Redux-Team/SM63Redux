@tool
class_name SmartSprite2D
extends Sprite2D


signal animation_finished
signal animation_looped


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


func _notification(what: int) -> void:
	if what == NOTIFICATION_POST_ENTER_TREE:
		if not canvas_texture:
			canvas_texture = CanvasTexture.new()
		texture = canvas_texture


func _process(delta: float) -> void:
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


func play(animation_name: StringName) -> void:
	if current_animation == animation_name and playing:
		return
	current_animation = animation_name
	_playback_time = 0.0
	current_frame = 0
	region_enabled = true
	playing = true


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
