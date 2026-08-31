@tool
class_name StateEffects
extends Resource


const INHERIT_BUS: StringName = &"Inherit"

@export var animation: StringName = &""
@export var restart_if_playing: bool = true
@export var speed_scale: float = 1.0
@export var stop_on_exit: bool = false
@export var lock_flipping: bool = false
@export_subgroup("Offset", "offset")
@export var offset_enabled: bool = false
@export var offset: Vector2 = Vector2.ZERO
@export_subgroup("Chain", "chain")
@export var chain: Array[StringName] = []
@export var chain_loop_last: bool = true
@export_subgroup("Loop", "loop_")
@export var loop_override: bool = false
@export var loop_enabled: bool = true
@export_group("Physics")
@export_flags_2d_physics var collision_mask_override: int = 0
@export_group("Animation Player", "player_")
@export var player_animation: StringName = &""
@export var player_reset_on_exit: bool = true
@export_group("Sound", "sfx_")
@export var sfx_enter: AudioStream
@export var sfx_enter_stop_on_exit: bool = false
@export var sfx_exit: AudioStream
@export var sfx_frame: AudioStream
@export var sfx_frame_indices: Array[int] = []
@export var sfx_bus: StringName = INHERIT_BUS
@export var sfx_spatial: bool = true


func enter(state: State) -> void:
	state.sfx_frame_index = -1
	if collision_mask_override != 0 and state.entity:
		state.mask_backup = state.entity.collision_mask
		state.entity.collision_mask = collision_mask_override
	if lock_flipping and state.entity is Player:
		(state.entity as Player).lock_flipping = true
	_play_animation(state)
	_play_player_animation(state)
	if sfx_enter:
		var player: Node = _play_sfx(state, sfx_enter)
		if sfx_enter_stop_on_exit:
			state.sfx_tracked = player


func exit(state: State) -> void:
	if state.mask_backup >= 0 and state.entity:
		state.entity.collision_mask = state.mask_backup
		state.mask_backup = -1
	if lock_flipping and state.entity is Player:
		(state.entity as Player).lock_flipping = false
	
	if is_instance_valid(state.sfx_tracked):
		state.sfx_tracked.stop()
		state.sfx_tracked.queue_free()
	state.sfx_tracked = null
	
	if state.sprite and state.sprite.animation_finished.is_connected(state._on_chain_advance):
		state.sprite.animation_finished.disconnect(state._on_chain_advance)
	
	if stop_on_exit and state.sprite:
		state.sprite.stop()
	if player_reset_on_exit and not player_animation.is_empty() and state.machine.animation_player:
		state.machine.animation_player.play(&"RESET")
	if sfx_exit:
		_play_sfx(state, sfx_exit)


func render_tick(state: State) -> void:
	if not sfx_frame or sfx_frame_indices.is_empty() or not state.sprite:
		return
	
	var frame: int = state.sprite.current_frame
	if frame == state.sfx_frame_index:
		return
	
	state.sfx_frame_index = frame
	if sfx_frame_indices.has(frame):
		_play_sfx(state, sfx_frame)


func _play_animation(state: State) -> void:
	if animation.is_empty() or not state.sprite:
		return
	if not restart_if_playing and state.sprite.playing and state.sprite.current_animation == animation:
		return
	
	state.chain_index = 0
	if loop_override:
		state.sprite.looping = chain.is_empty() and loop_enabled
	state.sprite.speed_scale = speed_scale
	state.sprite.play(animation)
	state.sprite.offset = offset if offset_enabled else Vector2.ZERO
	if not chain.is_empty():
		state.sprite.animation_finished.connect(state._on_chain_advance, CONNECT_ONE_SHOT)


func advance_chain(state: State) -> void:
	if not state.sprite or state.chain_index >= chain.size():
		return
	
	var next: StringName = chain.get(state.chain_index)
	state.chain_index += 1
	var is_last: bool = state.chain_index >= chain.size()
	if loop_override:
		state.sprite.looping = is_last and chain_loop_last
	state.sprite.play(next)
	if not is_last:
		state.sprite.animation_finished.connect(state._on_chain_advance, CONNECT_ONE_SHOT)


func _play_player_animation(state: State) -> void:
	if player_animation.is_empty() or not state.machine.animation_player:
		return
	state.machine.animation_player.play(player_animation)


func _play_sfx(state: State, stream: AudioStream) -> Node:
	var bus: StringName = sfx_bus
	if bus.is_empty() or bus == INHERIT_BUS:
		bus = state.machine.default_sfx_bus
	
	if sfx_spatial and state.sprite:
		return SFX.play_tracked_at(stream, state.sprite, bus)
	return SFX.play_tracked(stream, bus)


func _validate_property(property: Dictionary) -> void:
	if property.name == &"sfx_bus":
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = _bus_hint_string()


func _bus_hint_string() -> String:
	var names: PackedStringArray = [String(INHERIT_BUS)]
	for i: int in AudioServer.get_bus_count():
		names.append(AudioServer.get_bus_name(i))
	return ",".join(names)
