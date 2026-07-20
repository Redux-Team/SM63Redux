@icon("uid://btg8b714itoxv")
@tool
class_name State
extends Node

## Bus value that defers to the owning [StateMachine]'s [member StateMachine.default_sfx_bus].
const SFX_INHERIT: StringName = &"Inherit"

## The [SmartSprite2D] linked to the [StateMachine].
var sprite: SmartSprite2D
## The [AnimationPlayer] linked to the [StateMachine].
var animation_player: AnimationPlayer

@export_group("State Machine")
## Outgoing [StateTransition]s, checked in array order — the first eligible one fires,
## so the top of the array is the highest priority.
@export var transitions: Array[StateTransition] = []
## How long in seconds this state will remain active before automatically calling [method done].
## A value of 0.0 disables the runtime limit.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var runtime: float = 0.0
## The minimum number of physics frames this state must stay active before any of its
## outgoing transitions are allowed to fire. Replaces ad-hoc "elapsed frames" guards.
@export var min_active_frames: int = 0
## This defines whether the state can actually be [b]held[/b] by the [StateMachine].
## if [code]true[/code], then this state only serves to check transitions when it is transitioned
## to, otherwise the [StateMachine] will use the previous state.
@export var is_passthrough: bool = false
## When this state is not the primary state, but a superstate, transitions will
## normally not be checked. If [code]true[/code], then transitions will be checked
## regardless of if this state is active as a superstate or primary state.
@export var always_transition: bool = false

@export_group("Sprite", "sprite_")
## The animation of the [SmartSprite2D].
@export var sprite_animation_name: StringName = ""
## If [code]true[/code], the sprite animation will restart from the beginning even if it is
## already playing the same animation when this state is entered.
@export var sprite_restart_if_playing: bool = true
## If [code]true[/code], overrides the sprite loop setting using [member sprite_loop]
## instead of the animation's default.
@export var sprite_override_loop: bool = false
## If [code]true[/code], prevents the sprite from flipping horizontally while this state
## is active. Automatically released on exit.
@export var sprite_lock_flipping: bool = false
## Whether the sprite animation loops. Only applied when [member sprite_override_loop] is [code]true[/code].
@export var sprite_loop: bool = true
## Playback speed multiplier applied to the sprite animation on enter.
@export var sprite_speed_scale: float = 1.0
## If [code]true[/code], stops the sprite animation when this state is exited.
@export var sprite_stop_on_exit: bool = false
@export_subgroup("Offset", "sprite_offset")
## Enables a positional offset applied to the sprite while this state is active.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "sprite_offset_") var sprite_offset_enabled: bool = false
## The pixel offset applied to the sprite when [member sprite_offset_enabled] is [code]true[/code].
@export var sprite_offset_value: Vector2 = Vector2.ZERO
@export_subgroup("Chain", "sprite_")
## A sequence of animation names played in order after [member sprite_animation_name] finishes.
@export var sprite_chain: Array[StringName] = []
## If [code]true[/code], the final animation in [member sprite_chain] will loop indefinitely.
@export var sprite_chain_loop_last: bool = true

@export_group("Collision", "collision_")
## The subset of the entity's [CollisionShape2D] nodes that should be enabled while this state
## is active. All others will be disabled on enter and restored on exit. If none set, it will
## stay with what it entered with.
@export var collision_enabled_shapes: Array[CollisionShape2D] = []
## The subset of the entity's [CollisionShape2D] nodes that should be disabled while this state
## is active. Only used when [member collision_enabled_shapes] is empty.
@export var collision_disabled_shapes: Array[CollisionShape2D] = []
@export_flags_2d_physics var collision_mask_override: int = 0

@export_group("Animation Player", "anim_")
## The [AnimationPlayer] animation to play when this state is entered.
@export var anim_animation: String

@export_group("SFX")
@export_subgroup("Enter", "sfx_enter_")
## Plays a sound each time this state is entered.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "sfx_enter_") var sfx_enter_enabled: bool = false
## The sound played on enter, unless a [member sfx_enter_variants] entry overrides it.
@export var sfx_enter_sound: AudioStream
## Audio bus to route through. [code]Inherit[/code] uses the [StateMachine]'s default bus.
@export var sfx_enter_bus: StringName = SFX_INHERIT
## Play positionally at the machine's sprite instead of globally.
@export var sfx_enter_spatial: bool = true
## If [code]true[/code], stops this sound when the state exits (for looping/sustained sounds).
@export var sfx_enter_stop_on_exit: bool = false
## Method called on the root node; its return value selects a [member sfx_enter_variants] entry.
@export var sfx_enter_method: StringName = &""
## Maps [member sfx_enter_method]'s return value to the [AudioStream] played, overriding the sound.
@export var sfx_enter_variants: Dictionary[Variant, AudioStream] = {}
@export_subgroup("Exit", "sfx_exit_")
## Plays a sound each time this state is exited.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "sfx_exit_") var sfx_exit_enabled: bool = false
## The sound played on exit, unless a [member sfx_exit_variants] entry overrides it.
@export var sfx_exit_sound: AudioStream
## Audio bus to route through. [code]Inherit[/code] uses the [StateMachine]'s default bus.
@export var sfx_exit_bus: StringName = SFX_INHERIT
## Play positionally at the machine's sprite instead of globally.
@export var sfx_exit_spatial: bool = true
## Method called on the root node; its return value selects a [member sfx_exit_variants] entry.
@export var sfx_exit_method: StringName = &""
## Maps [member sfx_exit_method]'s return value to the [AudioStream] played, overriding the sound.
@export var sfx_exit_variants: Dictionary[Variant, AudioStream] = {}
@export_subgroup("Frame", "sfx_frame_")
## Plays a sound whenever the sprite lands on one of [member sfx_frame_indices].
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "sfx_frame_") var sfx_frame_enabled: bool = false
## The sound played on a frame hit, unless a [member sfx_frame_variants] entry overrides it.
@export var sfx_frame_sound: AudioStream
## The sprite frame indices that fire the sound.
@export var sfx_frame_indices: Array[int] = []
## Audio bus to route through. [code]Inherit[/code] uses the [StateMachine]'s default bus.
@export var sfx_frame_bus: StringName = SFX_INHERIT
## Play positionally at the machine's sprite instead of globally.
@export var sfx_frame_spatial: bool = true
## Method called on the root node; its return value selects a [member sfx_frame_variants] entry.
@export var sfx_frame_method: StringName = &""
## Maps [member sfx_frame_method]'s return value to the [AudioStream] played, overriding the sound.
@export var sfx_frame_variants: Dictionary[Variant, AudioStream] = {}
@export_subgroup("Interval", "sfx_interval_")
## Plays a sound every [member sfx_interval_seconds] while this state is active.
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "sfx_interval_") var sfx_interval_enabled: bool = false
## The sound played each interval, unless a [member sfx_interval_variants] entry overrides it.
@export var sfx_interval_sound: AudioStream
## Seconds between plays. A value of 0.0 never fires.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var sfx_interval_seconds: float = 0.0
## Audio bus to route through. [code]Inherit[/code] uses the [StateMachine]'s default bus.
@export var sfx_interval_bus: StringName = SFX_INHERIT
## Play positionally at the machine's sprite instead of globally.
@export var sfx_interval_spatial: bool = true
## Method called on the root node; its return value selects a [member sfx_interval_variants] entry.
@export var sfx_interval_method: StringName = &""
## Maps [member sfx_interval_method]'s return value to the [AudioStream] played, overriding the sound.
@export var sfx_interval_variants: Dictionary[Variant, AudioStream] = {}

var state_machine: StateMachine
var root_node: Node
var entity: Entity:
	get:
		if root_node is Entity:
			return root_node as Entity
		return null
var player: Player:
	get:
		if root_node is Player:
			return root_node as Player
		return null
var _sprite_chain_index: int = 0
var _pre_entered: bool = false
var _collision_snapshot: Dictionary = {}
var _original_collision_mask: int = 0
var _mask_overridden: bool = false
var _sfx_last_frame: int = -1
var _sfx_accum: float = 0.0
var _sfx_active_players: Array[Node] = []


func _validate_property(property: Dictionary) -> void:
	if property.name.begins_with("_") and not ReduxPlugin.SHOW_INTERNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
	if property.name == "transitions":
		property.usage |= PROPERTY_USAGE_ALWAYS_DUPLICATE
	if property.name in [&"sfx_enter_bus", &"sfx_exit_bus", &"sfx_frame_bus", &"sfx_interval_bus"]:
		property.hint = PROPERTY_HINT_ENUM
		property.hint_string = _sfx_bus_hint_string()
	if property.name == "sprite_animation_name":
		var sm: StateMachine = _get_state_machine()
		var frames: SpriteFrames = null
		if sm and sm.sprite and sm.sprite.diffuse_frames:
			frames = sm.sprite.diffuse_frames
		elif sprite and sprite.diffuse_frames:
			frames = sprite.diffuse_frames
		if frames:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(frames.get_animation_names())
	if property.name == "anim_animation":
		var sm: StateMachine = _get_state_machine()
		if sm and sm.animation_player:
			property.hint = PROPERTY_HINT_ENUM
			property.hint_string = ",".join(sm.animation_player.get_animation_list())


# Walks up the scene tree to find the nearest parent StateMachine.
func _get_state_machine() -> StateMachine:
	if state_machine:
		return state_machine
	var current: Node = get_parent()
	while current:
		if current is StateMachine:
			return current as StateMachine
		current = current.get_parent()
	return null


func done(force: bool = false) -> void:
	if state_machine:
		state_machine._notify_done(force)


## Returns this state's identity name in snake_case, derived from the node name.
func get_internal_name() -> String:
	return String(name).to_snake_case()


## Returns the time this state has been active for, in seconds.
func get_elapsed_time() -> float:
	if not state_machine or state_machine._current_state != self:
		return 0.0
	return state_machine._elapsed_time


## Returns the amount of render frames this state has been active for.
func get_elapsed_frames() -> int:
	if not state_machine or state_machine._current_state != self:
		return 0
	return state_machine._elapsed_frames


## Returns the amount of physics frames this state has been active for.
func get_elapsed_physics_frames() -> int:
	if not state_machine or state_machine._current_state != self:
		return 0
	return state_machine._elapsed_physics_frames


## Returns the last active state before this one.
func get_last_state() -> State:
	if not state_machine or state_machine._current_state != self:
		return null
	return state_machine._last_state


## Only valid for [method _on_exit] and [method _post_exit]. Will return the next
## state that the StateMachine is transitioning to.
func get_next_state() -> State:
	if not state_machine:
		return null
	return state_machine._next_state


## Returns the root superstate that is being ran on the StateMachine, if this node
## is the root, null is returned.
func get_superstate_root() -> State:
	if not state_machine:
		return null
	var superstates: Array[State] = state_machine._active_superstates
	if superstates.is_empty():
		return null
	return superstates.front()


## Returns the parent superstate that is being ran on the StateMachine, if this node
## has no superstate parent, null is returned.
func get_superstate_parent() -> State:
	if not state_machine:
		return null
	var superstates: Array[State] = state_machine._active_superstates
	if superstates.is_empty():
		return null
	if self == state_machine._current_state:
		return superstates.back()
	var idx: int = superstates.find(self)
	if idx <= 0:
		return null
	return superstates.get(idx - 1)


## Returns the last transition triggered by the StateMachine.
func get_last_transition() -> StateTransition:
	if not state_machine:
		return null
	return state_machine._last_transition


## Returns whether this state is currently active in the state machine or not. This
## includes whether it is being ran as a superstate or not.
func is_active() -> bool:
	if not state_machine:
		return false
	return state_machine._is_state_in_stack(self)


## Returns whether this state is the primary active state in the state machine.
func is_primary_active() -> bool:
	if not state_machine:
		return false
	return state_machine._current_state == self


## Simple way to await time.
func pause(time: float) -> void:
	await get_tree().create_timer(time).timeout


## Defines whether the state machine can transition to this state. If false is
## returned even when the transition case is true, it will not go through and
## it will remain on the previous state, no exit methods from this state will be called.
func _can_enter() -> bool:
	return true


## Defines whether the state machine can transition from this state. If false is
## returned even when the transition case is true, it will not go through and
## it will remain on this state, no exit methods from this state will be called.
func _can_exit() -> bool:
	return true


## Called every render frame, semantically used to handle sprite behavior.
func _sprite_rules() -> void:
	pass


## Called before the state is entered, just after [method _on_exit]
## is called on the previous state. Useful for ensuring behavior before any
## tick method is called.
func _pre_enter() -> void:
	pass


## Called after [method _post_exit] is called on the previous state and this
## state has officially been entered.
func _on_enter() -> void:
	pass


## Called every render frame while the state is active. Use for visual-only
## behavior that should update at the display refresh rate.
func _on_render_tick(delta: float) -> void:
	pass


## Similar to [method _physics_process], but will only be called when the state
## is active. This is the gameplay clock: all logic and transitions run here.
func _on_physics_tick(delta: float) -> void:
	pass


## Called before exiting the state and before [method _pre_enter] is called on the
## next state.
func _on_exit() -> void:
	pass


## Called after completely exiting the state and before [method _on_enter] is
## called on the next state.
func _post_exit() -> void:
	pass


func __sprite_enter() -> void:
	if not sprite or sprite_animation_name.is_empty():
		return
	if not sprite_restart_if_playing and sprite.playing and sprite.current_animation == sprite_animation_name:
		return
	_sprite_chain_index = 0
	if sprite.animation_finished.is_connected(__sprite_chain_advance):
		sprite.animation_finished.disconnect(__sprite_chain_advance)
	if sprite_override_loop:
		sprite.looping = sprite_chain.is_empty() and sprite_loop
	sprite.speed_scale = sprite_speed_scale
	sprite.play(sprite_animation_name)
	sprite.offset = _resolve_sprite_offset()
	if sprite_lock_flipping and entity and entity is Player:
		player.lock_flipping = true
	if not sprite_chain.is_empty():
		sprite.animation_finished.connect(__sprite_chain_advance, CONNECT_ONE_SHOT)


func __sprite_exit() -> void:
	if sprite and sprite.animation_finished.is_connected(__sprite_chain_advance):
		sprite.animation_finished.disconnect(__sprite_chain_advance)
	if entity and entity is Player:
		player.lock_flipping = false
	if not sprite or not sprite_stop_on_exit:
		return
	sprite.stop()


func _resolve_sprite_offset() -> Vector2:
	if sprite_offset_enabled:
		return sprite_offset_value
	if not state_machine:
		return Vector2.ZERO
	var superstates: Array[State] = state_machine._active_superstates
	for i: int in range(superstates.size() - 1, -1, -1):
		if superstates.get(i).sprite_offset_enabled:
			return superstates.get(i).sprite_offset_value
	return Vector2.ZERO


func __sprite_chain_advance() -> void:
	if not is_active() or _sprite_chain_index >= sprite_chain.size():
		return
	var next: StringName = sprite_chain.get(_sprite_chain_index)
	_sprite_chain_index += 1
	var is_last: bool = _sprite_chain_index >= sprite_chain.size()
	if sprite_override_loop:
		sprite.looping = is_last and sprite_chain_loop_last
	sprite.play(next)
	if not is_last:
		sprite.animation_finished.connect(__sprite_chain_advance, CONNECT_ONE_SHOT)


func __collision_enter() -> void:
	if not state_machine:
		return
	var entity_node: Entity = state_machine._root_node as Entity
	if not entity_node:
		return
	_mask_overridden = false
	if collision_mask_override:
		_original_collision_mask = entity_node.collision_mask
		entity_node.collision_mask = collision_mask_override
		_mask_overridden = true
	if entity_node.collision_shapes.is_empty():
		return
	var enabled: Array[CollisionShape2D] = _resolve_collision_shapes()
	var disabled: Array[CollisionShape2D] = _resolve_disabled_collision_shapes()
	if enabled.is_empty() and disabled.is_empty():
		return
	_collision_snapshot.clear()
	for shape: CollisionShape2D in entity_node.collision_shapes:
		_collision_snapshot[shape] = shape.disabled
		if not enabled.is_empty():
			shape.set_deferred("disabled", shape not in enabled)
		elif shape in disabled:
			shape.set_deferred("disabled", true)


func __collision_exit() -> void:
	if not state_machine:
		return
	var entity_node: Entity = state_machine._root_node as Entity
	if not entity_node:
		return
	if _mask_overridden:
		entity_node.collision_mask = _original_collision_mask
		_mask_overridden = false
	if _collision_snapshot.is_empty():
		return
	for shape: CollisionShape2D in _collision_snapshot:
		shape.disabled = _collision_snapshot.get(shape, false)
	_collision_snapshot.clear()


func _resolve_collision_shapes() -> Array[CollisionShape2D]:
	if not collision_enabled_shapes.is_empty():
		return collision_enabled_shapes
	var superstates: Array[State] = state_machine._active_superstates
	for i: int in range(superstates.size() - 1, -1, -1):
		if not superstates.get(i).collision_enabled_shapes.is_empty():
			return superstates.get(i).collision_enabled_shapes
	return []


func _resolve_disabled_collision_shapes() -> Array[CollisionShape2D]:
	if not collision_disabled_shapes.is_empty():
		return collision_disabled_shapes
	var superstates: Array[State] = state_machine._active_superstates
	for i: int in range(superstates.size() - 1, -1, -1):
		if not superstates.get(i).collision_disabled_shapes.is_empty():
			return superstates.get(i).collision_disabled_shapes
	return []


func __animation_enter() -> void:
	if not animation_player or animation_player.get_animation_list().is_empty() or anim_animation.is_empty():
		return
	animation_player.play(anim_animation)


func __animation_exit() -> void:
	if animation_player:
		animation_player.play(&"RESET")


func __sfx_enter() -> void:
	_sfx_last_frame = -1
	_sfx_accum = 0.0
	if sfx_enter_enabled:
		_play_sfx(sfx_enter_sound, sfx_enter_method, sfx_enter_variants, sfx_enter_bus, sfx_enter_spatial, sfx_enter_stop_on_exit)


func __sfx_exit() -> void:
	_stop_tracked_sfx()
	if sfx_exit_enabled:
		_play_sfx(sfx_exit_sound, sfx_exit_method, sfx_exit_variants, sfx_exit_bus, sfx_exit_spatial, false)


func __sfx_frame_tick() -> void:
	if not sfx_frame_enabled or not sprite:
		return
	var frame: int = sprite.current_frame
	if frame == _sfx_last_frame:
		return
	_sfx_last_frame = frame
	if sfx_frame_indices.has(frame):
		_play_sfx(sfx_frame_sound, sfx_frame_method, sfx_frame_variants, sfx_frame_bus, sfx_frame_spatial, false)


func __sfx_interval_tick(delta: float) -> void:
	if not sfx_interval_enabled or sfx_interval_seconds <= 0.0:
		return
	_sfx_accum += delta
	if _sfx_accum >= sfx_interval_seconds:
		_sfx_accum -= sfx_interval_seconds
		_play_sfx(sfx_interval_sound, sfx_interval_method, sfx_interval_variants, sfx_interval_bus, sfx_interval_spatial, false)


func _stop_tracked_sfx() -> void:
	for player: Node in _sfx_active_players:
		if is_instance_valid(player):
			player.stop()
			player.queue_free()
	_sfx_active_players.clear()


func _resolve_sfx_sound(sound: AudioStream, method: StringName, variants: Dictionary) -> AudioStream:
	if not method.is_empty() and state_machine:
		var root: Node = state_machine.get_root()
		var resolved_method: StringName = StringName(String(method).trim_suffix("()").strip_edges())
		if root and root.has_method(resolved_method):
			var key: Variant = root.call(resolved_method)
			if variants.has(key):
				return variants.get(key)
	return sound


func _play_sfx(sound: AudioStream, method: StringName, variants: Dictionary, bus: StringName, spatial: bool, track: bool) -> void:
	if not state_machine:
		return
	var source: AudioStream = _resolve_sfx_sound(sound, method, variants)
	if not source:
		return
	var resolved_bus: StringName = _resolve_sfx_bus(bus)
	var at: Node2D = null
	if spatial:
		at = state_machine.sprite as Node2D
		if not at:
			at = state_machine.get_root() as Node2D
	var player: Node = SFX.play_tracked_at(source, at, resolved_bus) if at else SFX.play_tracked(source, resolved_bus)
	if track and player:
		_sfx_active_players.append(player)


func _resolve_sfx_bus(bus: StringName) -> StringName:
	if bus.is_empty() or bus == SFX_INHERIT:
		return state_machine.default_sfx_bus if state_machine else &"SFX"
	return bus


func _sfx_bus_hint_string() -> String:
	var names: PackedStringArray = [String(SFX_INHERIT)]
	for i: int in AudioServer.get_bus_count():
		names.append(AudioServer.get_bus_name(i))
	return ",".join(names)


func _to_string() -> String:
	return name
