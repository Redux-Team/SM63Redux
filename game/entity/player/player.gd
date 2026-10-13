class_name Player
extends Entity

signal swimming_changed(swimming: bool)

const TERRAIN_LAYER_FIRST: int = 25

@export_group("Physics")
## Downward acceleration applied every physics tick, before the active states' gravity scales.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s²") var gravity: float = 900.0
## Multiplier on gravity while the water check reports the player as submerged.
@export var water_gravity_scale: float = 0.1
## Time for floor friction alone to halve horizontal speed; scaled by the friction modifiers.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var floor_friction_halflife: float = 0.1482
@export_group("Terrain")
## Downward ray used to read slope angles and the terrain under the player's feet.
@export var floor_raycast: RayCast2D
## Terrain names matched, in order, against the collision layers starting at TERRAIN_LAYER_FIRST.
@export var terrains: Array[StringName] = [&"grass", &"snow", &"cloud", &"ice", &"metal"]
@export_group("Nodes")
## The FLUDD backpack driven alongside the state machine each physics tick.
@export var fludd: PlayerFludd
## Audio effects added to the master bus while underwater and removed on exit.
@export var submerged_bus_effects: Array[AudioEffect]

## Buffered player input, polled once per physics tick.
var controls: PlayerInput = PlayerInput.new()
## Horizontal input for this tick; turbo holds it at the facing direction when no direction is pressed.
var move_input: float = 0.0
## Stops the sprite from turning to face the move input.
var lock_flipping: bool = false
## Allows grounded states to start a jump.
var can_jump: bool = true
## Allows horizontal swimming input to accelerate the player.
var can_walk: bool = true
## Allows airborne states to start a dive.
var can_dive: bool = true
## Allows a ground pound to start from the air.
var can_ground_pound: bool = true
## How many jumps of the current chain have been performed.
var jump_chain: int = 0
## Time left on the ground before the jump chain resets.
var jump_chain_timer: float = 0.0
## Replaces the grounded run speed when above zero.
var ground_speed_override: float = 0.0
## Replaces the air control max speed when above zero.
var air_speed_override: float = 0.0
## Named gravity multipliers that stack with the active states' gravity scales.
var gravity_modifiers: ModifierStack = ModifierStack.new()
## Named floor friction multipliers, such as the floorslide and turbo modifiers.
var friction_modifiers: ModifierStack = ModifierStack.new()


func _physics_process(delta: float) -> void:
	controls.poll(delta)
	move_input = controls.move
	if fludd.is_turbo_active() and is_zero_approx(move_input):
		move_input = float(get_facing())
	
	gravity_modifiers.tick(delta)
	friction_modifiers.tick(delta)
	machine.tick(delta)
	if not lock_flipping and not is_zero_approx(move_input):
		sprite.flip_h = move_input < 0.0
	
	fludd.tick(delta)
	if not _velocity_lock:
		_integrate(delta)


func _integrate(delta: float) -> void:
	var start: Vector2 = velocity
	velocity.y = minf(velocity.y + get_gravity_strength() * delta, get_fall_speed_cap())
	var end: Vector2 = velocity
	velocity.y = (start.y + end.y) * 0.5
	var mid: Vector2 = velocity
	_try_step()
	move_and_slide()
	velocity += end - mid


func drive(input: float, max_speed: float, acceleration: float, turn_acceleration: float, turn_threshold: float, drag_rate: float, delta: float) -> void:
	var direction: float = signf(input)
	var cap: float = max_speed * absf(input)
	var speed: float = velocity.x * direction
	if speed >= cap:
		speed = maxf(Motion.drift(speed, 0.0, drag_rate, delta), cap)
	else:
		var turning: bool = speed < -turn_threshold
		speed = minf(Motion.drift(speed, turn_acceleration if turning else acceleration, drag_rate, delta), cap)
	
	velocity.x = speed * direction


func brake(deceleration: float, drag_rate: float, delta: float) -> void:
	var speed: float = maxf(Motion.drift(absf(velocity.x), -deceleration, drag_rate, delta), 0.0)
	velocity.x = speed * signf(velocity.x)


func get_gravity_strength() -> float:
	var scale: float = gravity_modifiers.product()
	for state: State in machine.get_active_states():
		scale *= (state as PlayerState).get_gravity_scale()
	
	if is_in_water():
		scale *= water_gravity_scale
	
	return gravity * scale


func get_fall_speed_cap() -> float:
	var cap: float = INF
	for state: State in machine.get_active_states():
		var limit: float = (state as PlayerState).max_fall_speed
		if limit > 0.0:
			cap = minf(cap, limit)
	
	return cap


func get_floor_drag_rate() -> float:
	return Motion.rate(floor_friction_halflife) * friction_modifiers.product()


func get_ground_speed(base: float) -> float:
	return ground_speed_override if ground_speed_override > 0.0 else base


func get_air_speed(base: float) -> float:
	return air_speed_override if air_speed_override > 0.0 else base


func get_facing() -> int:
	return -1 if sprite.flip_h else 1


func get_facing_velocity() -> float:
	return velocity.x * get_facing()


func is_moving_with_facing() -> bool:
	return signf(move_input) == float(get_facing())


func is_moving_against_facing() -> bool:
	return signf(move_input) == float(-get_facing())


func is_crouching() -> bool:
	return controls.is_held(&"crouch") and is_on_floor()


func is_swim_pressed(buffer: float) -> bool:
	return controls.was_pressed_within(&"jump", buffer) and not fludd.is_aiming()


func get_slope_angle(fallback: float) -> float:
	if not floor_raycast.is_colliding():
		return fallback
	
	return floor_raycast.get_collision_normal().angle() + PI / 2.0


func get_terrain() -> StringName:
	if not floor_raycast.is_colliding():
		return &""
	
	var collider: CollisionObject2D = floor_raycast.get_collider() as CollisionObject2D
	if not collider:
		return &""
	
	for i: int in terrains.size():
		if collider.get_collision_layer_value(TERRAIN_LAYER_FIRST + i):
			return terrains.get(i)
	
	return StringName(collider.get_meta(&"terrain", ""))


func get_debug_text() -> String:
	return "State: %s\nAnimation: %s\nVelocity: %s\n" % [machine.get_state(), sprite.current_animation, velocity]


func _on_feet_landed(_hurt_box: HurtBox) -> void:
	if velocity.y < 0.0 or machine.is_active(&"Stomp") or machine.is_active(&"GroundPound"):
		return
	
	var dive: DiveState = machine.get_state() as DiveState
	if dive:
		dive.stomp()
		return
	
	machine.change_state(&"Stomp")


func _on_water_entered() -> void:
	swimming_changed.emit(true)
	for effect: AudioEffect in submerged_bus_effects:
		AudioServer.add_bus_effect(0, effect)


func _on_water_exited() -> void:
	swimming_changed.emit(false)
	for _effect: AudioEffect in submerged_bus_effects:
		AudioServer.remove_bus_effect(0, 0)
