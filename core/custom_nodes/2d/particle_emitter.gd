@tool
class_name ParticleEmitter
extends CPUParticles2D


@export var high_particle_amount: int
@export var medium_particle_amount: int
@export var low_particle_amount: int
@export_group("Animated")
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "Animated") var animated: bool:
	set(a):
		animated = a
		notify_property_list_changed()
@export var sprite_frames: SpriteFrames
@export var animation: StringName = &"default"


var _frame: int = 0
var _elapsed: float = 0.0


func _ready() -> void:
	amount = high_particle_amount


func _process(delta: float) -> void:
	if not animated or not sprite_frames or not sprite_frames.has_animation(animation):
		return
	var fps: float = sprite_frames.get_animation_speed(animation)
	if fps <= 0.0:
		return
	_elapsed += delta
	var frame_duration: float = 1.0 / fps
	if _elapsed < frame_duration:
		return
	_elapsed = fmod(_elapsed, frame_duration)
	var count: int = sprite_frames.get_frame_count(animation)
	_frame = (_frame + 1) % count if sprite_frames.get_animation_loop(animation) else mini(_frame + 1, count - 1)
	texture = sprite_frames.get_frame_texture(animation, _frame)


func _validate_property(property: Dictionary) -> void:
	if property.get("name") == "texture" and animated:
		property.set("usage", PROPERTY_USAGE_NO_EDITOR)
