class_name StateSFXEntry
extends Resource

enum InterruptPolicy {
	CANCEL,
	PLAY_ANYWAY,
	PLAY_IF_SUPERSTATE_ACTIVE,
}


@export var playlist: Playlist
@export var chance: float = 1.0
@export var spatial: bool = true
@export var pool_id: StringName = &"default"
@export var bus: Playlist.Bus = Playlist.Bus.SFX_
@export var interrupt_policy: InterruptPolicy = InterruptPolicy.PLAY_ANYWAY
@export var max_stack: int = 1
@export_group("Pitch & Volume")
@export var pitch_range: Vector2 = Vector2(1.0, 1.0)
@export var volume_db: float = 0.0
@export var pitch_property: StringName = &""
@export var pitch_property_range: Vector2 = Vector2(0.0, 1.0)
@export var volume_property: StringName = &""
@export var volume_property_range: Vector2 = Vector2(0.0, 1.0)
@export_group("Exit Behaviour")
@export var stop_on_exit: bool = false
@export var free_pool_on_exit: bool = false
@export_group("Frame Trigger")
@export var frame_range: Vector2i = Vector2i(-1, -1)

var _frame_triggered: bool = false


func _get_bus_name() -> StringName:
	match bus:
		Playlist.Bus.MASTER: return &"Master"
		Playlist.Bus.MUSIC: return &"Music"
		Playlist.Bus.SFX_: return &"SFX"
		Playlist.Bus.PLAYER: return &"Player"
	return &"Master"


func _resolve_pitch(root_node: Node) -> float:
	var base: float = randf_range(pitch_range.x, pitch_range.y)
	if pitch_property.is_empty() or not root_node:
		return base
	var val: float = float(root_node.get(pitch_property))
	var t: float = inverse_lerp(pitch_property_range.x, pitch_property_range.y, val)
	return lerp(pitch_range.x, pitch_range.y, clampf(t, 0.0, 1.0))


func _resolve_volume(root_node: Node) -> float:
	if volume_property.is_empty() or not root_node:
		return volume_db
	var val: float = float(root_node.get(volume_property))
	var t: float = inverse_lerp(volume_property_range.x, volume_property_range.y, val)
	return lerp(-80.0, 0.0, clampf(t, 0.0, 1.0))


func reset_frame_trigger() -> void:
	_frame_triggered = false


func check_frame_trigger(frame: int) -> bool:
	if frame_range.x < 0 or frame_range.y < 0:
		return false
	var in_range: bool = frame >= frame_range.x and frame <= frame_range.y
	if in_range and not _frame_triggered:
		_frame_triggered = true
		return true
	if not in_range:
		_frame_triggered = false
	return false
