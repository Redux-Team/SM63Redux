@icon("uid://btg8b714itoxv")
@tool
class_name State
extends Node

## The [SmartSprite2D] linked to the [StateMachine].
var sprite: SmartSprite2D
## The [AnimationPlayer] linked to the [StateMachine].
var animation_player: AnimationPlayer

@export_group("State Machine")
## How long in seconds this state will remain active before automatically calling [method done].
## A value of 0.0 disables the runtime limit.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var runtime: float = 0.0
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

@export_group("SFX", "sfx_")
## SFX entry played when this state is entered.
@export var sfx_enter: StateSFXEntry
## SFX entry played when this state is exited.
@export var sfx_exit: StateSFXEntry
## SFX entry played every process tick while this state is active.
@export var sfx_tick: StateSFXEntry
## SFX entry triggered by specific sprite frames while this state is active.
@export var sfx_frame: StateSFXEntry

@export_group("Animation Player", "anim_")
## The [AnimationPlayer] animation to play when this state is entered.
@export var anim_animation: String

@export_group("Internal")
@export var __editor_name: StringName
@export var __editor_position: Vector2
@export var __editor_uuid: StringName
@export var __editor_superstate_uuid: StringName
@export var __editor_entry_uuid: StringName
@export var __editor_superstate_wire_uuid: StringName

var state_machine: StateMachine
var root_node: Node
var entity: Entity:
	get:
		if root_node is Entity:
			return root_node as Entity
		else:
			print_debug("root_node passed as Entity when type does not match!")
			return null
var player: Player:
	get:
		if root_node is Player:
			return root_node as Player
		else:
			print_debug("root_node passed as Player when type does not match!")
			return null
var _sprite_chain_index: int = 0
var _pre_entered: bool = false
var _collision_snapshot: Array[CollisionShape2D] = []


func _ready() -> void:
	if not Engine.is_editor_hint() and runtime > 0:
		get_tree().process_frame.connect(func() -> void:
			if get_elapsed_time() >= runtime:
				done()
		)


func _validate_property(property: Dictionary) -> void:
	if property.name.begins_with("_") and not ReduxPlugin.SHOW_INTERNAL:
		property.usage = PROPERTY_USAGE_NO_EDITOR
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


## Returns the state name parsed by the internal editor and state machine,
## which is in snake case.
func get_internal_name() -> String:
	return __editor_name.to_snake_case()


## Returns the time this state has been active for, in seconds.
func get_elapsed_time() -> float:
	if not state_machine or state_machine._current_state != self:
		return 0.0
	return state_machine._elapsed_time


## Returns the amount of process frames this state has been active for.
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
	return null


## Returns the root superstate that is being ran on the StateMachine, if this node
## is the root, null is returned.
func get_superstate_root() -> State:
	if not state_machine:
		return null
	var superstates: Array[State] = state_machine._active_superstates
	if superstates.is_empty():
		return null
	return superstates[0]


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
	return superstates[idx - 1]

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


## Called every process frame, semantically used to handle sprite behavior
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


## Similar to [method _process], but will only be called when the state
## is active. You may call [method _process] for behavior that must be ran
## regardless of which state is active.
func _on_tick(delta: float) -> void:
	pass


## Similar to [method _on_tick], but will only be called when the state
## is inactive.
func _on_tick_inactive(delta: float) -> void:
	pass


## Similar to [method _physics_process], but will only be called when the state
## is active. You may call [method _physics_process] for behavior that must be ran
## regardless of which state is active.
func _on_physics_tick(delta: float) -> void:
	pass


## Similar to [method _on_physics_tick], but will only be called when the state
## is inactive.
func _on_physics_tick_inactive(delta: float) -> void:
	pass


## Similar to [method _input], but will only be called when the state
## is active. You may call [method _input] for behavior that must be ran
## regardless of which state is active.
func _on_input(event: InputEvent) -> void:
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
	if sprite_lock_flipping:
		player.lock_flipping = true
	if not sprite_chain.is_empty():
		sprite.animation_finished.connect(__sprite_chain_advance, CONNECT_ONE_SHOT)


func __sprite_exit() -> void:
	if sprite and sprite.animation_finished.is_connected(__sprite_chain_advance):
		sprite.animation_finished.disconnect(__sprite_chain_advance)
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
		if superstates[i].sprite_offset_enabled:
			return superstates[i].sprite_offset_value
	return Vector2.ZERO


func __sprite_chain_advance() -> void:
	if not is_active() or _sprite_chain_index >= sprite_chain.size():
		return
	var next: StringName = sprite_chain[_sprite_chain_index]
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
	if not entity_node or entity_node.collision_shapes.is_empty():
		return
	var shapes: Array[CollisionShape2D] = _resolve_collision_shapes()
	if shapes.is_empty():
		return
	_collision_snapshot.clear()
	for shape: CollisionShape2D in entity_node.collision_shapes:
		if not shape.disabled:
			_collision_snapshot.append(shape)
		shape.disabled = shape not in shapes


func __collision_exit() -> void:
	if not state_machine or _collision_snapshot.is_empty():
		return
	var entity_node: Entity = state_machine._root_node as Entity
	if not entity_node or entity_node.collision_shapes.is_empty():
		return
	for shape: CollisionShape2D in entity_node.collision_shapes:
		shape.disabled = shape not in _collision_snapshot
	_collision_snapshot.clear()


func _resolve_collision_shapes() -> Array[CollisionShape2D]:
	if not collision_enabled_shapes.is_empty():
		return collision_enabled_shapes
	var superstates: Array[State] = state_machine._active_superstates
	for i: int in range(superstates.size() - 1, -1, -1):
		if not superstates[i].collision_enabled_shapes.is_empty():
			return superstates[i].collision_enabled_shapes
	return []


func __animation_enter() -> void:
	if not animation_player or animation_player.get_animation_list().is_empty() or anim_animation.is_empty():
		return
	animation_player.play(anim_animation)


func __animation_exit() -> void:
	animation_player.play(&"RESET")


func _to_string() -> String:
	return name
