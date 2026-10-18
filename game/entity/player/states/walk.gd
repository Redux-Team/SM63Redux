extends PlayerState

@export_group("Transitions")
## Input strength below which walking can stop.
@export var stop_input_threshold: float = 0.1
## Speed below which walking stops without input.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var stop_speed: float = 0.5
## Speed below which crouch starts a crouch instead of a floorslide.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var crouch_max_speed: float = 50.0
## How long a jump press stays valid after it was pressed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var jump_buffer: float = 0.25
@export_group("Gait")
## Input strength needed for the walk animation.
@export var walk_input_threshold: float = 0.1
## Input strength needed for the run animation.
@export var run_input_threshold: float = 0.7
## Speed below which the walk animation is used without input.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var animation_stop_speed: float = 30.0
## Speed the animation speed curve is normalized against.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var animation_reference_speed: float = 220.0
## Animation speed over normalized running speed.
@export var animation_speed_curve: Curve
@export var turbo_animation: StringName = &"turbo_run"
@export_group("Footsteps")
## Sounds played on footstep frames.
@export var footstep_bank: SFXBank
## Dust burst emitted on footstep frames.
@export var footstep_particles: AnimatedParticles
## Speed needed before footsteps emit dust.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var footstep_particle_min_speed: float = 20.0
## Animation frames that trigger a footstep, per animation.
@export var footstep_frames: Dictionary[StringName, PackedInt32Array] = {
	&"walk_loop": PackedInt32Array([0, 4]),
	&"run_loop": PackedInt32Array([0, 4]),
}

var _footstep_frame: int = -1


func _enter() -> void:
	_footstep_frame = -1
	_update_gait()


func _tick(_delta: float) -> void:
	_update_gait()


func _render_tick(_delta: float) -> void:
	var frame: int = sprite.current_frame
	if frame == _footstep_frame:
		return
	
	_footstep_frame = frame
	if footstep_frames.get(sprite.current_animation, PackedInt32Array()).has(frame):
		_play_footstep()


func _next() -> StringName:
	var grounded: bool = player.is_on_floor()
	if not grounded and player.velocity.y >= 0.0:
		return &"Fall"
	if absf(player.move_input) < stop_input_threshold and absf(player.velocity.x) < stop_speed:
		return &"Idle"
	if grounded and controls.is_just_pressed(&"crouch"):
		if absf(player.velocity.x) <= crouch_max_speed:
			return &"Crouch"
		if player.is_moving_with_facing():
			return &"Floorslide"
	if controls.is_held(&"spin"):
		return &"Spin"
	if grounded and player.can_jump and controls.is_buffered(&"jump", jump_buffer):
		return &"BaseJump"
	return &""


func _update_gait() -> void:
	var input_strength: float = absf(player.move_input)
	var animation: StringName = sprite.current_animation
	if player.is_turbo_striking():
		animation = turbo_animation
	elif input_strength >= walk_input_threshold:
		animation = player.get_cap_animation(&"run_loop" if input_strength >= run_input_threshold else &"walk_loop")
	elif absf(player.velocity.x) <= animation_stop_speed:
		animation = &"walk_loop"
	
	if sprite.current_animation != animation:
		sprite.play(animation)
	
	if animation_speed_curve:
		sprite.speed_scale = animation_speed_curve.sample(clampf(absf(player.velocity.x) / animation_reference_speed, 0.0, 1.0))


func _play_footstep() -> void:
	if footstep_bank:
		footstep_bank.play_sfx_at(player.global_position, footstep_bank.bank_group, player, sprite)
	if footstep_particles and absf(player.velocity.x) > footstep_particle_min_speed:
		footstep_particles.burst()
