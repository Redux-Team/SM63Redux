extends FluddMode

@export_group("Hover")
## Multiplier on upward speed when hovering starts at full power.
@export var full_power_impulse: float = 1.3
## Caps upward speed from the full power impulse.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var max_impulse_speed: float = 500.0
## Upward speed lift pulls toward before the power factor.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var lift_speed: float = 200.0
## Upward speed above which lift is used instead of settling.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var lift_threshold: float = 50.0
## Lift multiplier at empty power.
@export var lift_factor_empty: float = 0.3
## Lift multiplier at full power.
@export var lift_factor_full: float = 0.8
## Time for lift to close half the gap to its target speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var lift_halflife: float = 0.0137
## Upward speed pulled toward once the hover settles.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var settle_speed: float = 200.0
## Time for settling to close half the gap to the settle speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var settle_halflife: float = 0.1096
@export_group("Hover Steering")
## Horizontal speed cap while hovering.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var max_speed: float = 120.0
## Time for horizontal speed to close half the gap to the hover cap.
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var speed_halflife: float = 0.3466
@export_group("Dive")
## Push along the body while diving.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2") var dive_force: float = 600.0
## Share of the dive push applied vertically.
@export var dive_vertical_factor: float = 0.0
## Upward acceleration while diving.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2") var dive_lift: float = 0.0
## Time for horizontal drag to halve speed while diving.
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var dive_drag_halflife_x: float = 0.3793
## Time for vertical drag to halve speed while diving.
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var dive_drag_halflife_y: float = 0.5718
@export_group("Floor Slide")
## Push along the body while floorsliding.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2")
var slide_force: float = 3000.0
## Share of the slide push applied vertically.
@export var slide_vertical_factor: float = 0.0
## Upward acceleration while floorsliding.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s^2") var slide_lift: float = 0.0
## Time for horizontal drag to halve speed while floorsliding.
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var slide_drag_halflife: float = 0.3793
@export_group("Submerged")
## Upward speed pulled toward underwater.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var submerged_speed: float = 1000.0
## Time to close half the gap to the underwater speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var submerged_halflife: float = 0.3

var _settled: bool = false


func _enter() -> void:
	_settled = false
	fludd.begin_spray(fludd.hover_sfx)


func _tick(delta: float) -> void:
	fludd.launch_off_ground()
	player.air_speed_override = 0.0
	match fludd.get_context():
		PlayerFludd.Context.FLOOR_SLIDE when player.is_on_floor():
			_push(slide_force, slide_vertical_factor, slide_lift, slide_drag_halflife, 0.0, delta)
		PlayerFludd.Context.DIVE, PlayerFludd.Context.FLOOR_SLIDE:
			_push(
					dive_force,
					dive_vertical_factor,
					dive_lift,
					dive_drag_halflife_x,
					dive_drag_halflife_y,
					delta,
			)
		PlayerFludd.Context.SUBMERGED:
			fludd.begin_spray_loop()
			player.velocity.y = \
					Motion.damp(player.velocity.y, -submerged_speed, submerged_halflife, delta)
		_:
			_hover(delta)
			_steer(delta)


func _exit() -> void:
	player.air_speed_override = 0.0
	fludd.end_spray()


func _hover(delta: float) -> void:
	var velocity_y: float = player.velocity.y
	if (
			velocity_y < 0.0
			and is_equal_approx(fludd.power, PlayerFludd.POWER_MAX)
			and not player.is_on_floor()
	):
		player.velocity.y = maxf(velocity_y * full_power_impulse, -max_impulse_speed)
	elif velocity_y < -lift_threshold and not _settled:
		var lift: float = \
				lerpf(lift_factor_empty, lift_factor_full, fludd.power / PlayerFludd.POWER_MAX)
		player.velocity.y = \
				minf(Motion.damp(velocity_y, -lift_speed * lift, lift_halflife, delta), velocity_y)
	else:
		_settled = true
		player.velocity.y = Motion.damp(velocity_y, -settle_speed, settle_halflife, delta)


func _steer(delta: float) -> void:
	player.air_speed_override = max_speed
	var target: float = \
			0.0 if is_zero_approx(player.move_input) else signf(player.velocity.x) * max_speed
	if is_zero_approx(player.move_input) or absf(player.velocity.x) > max_speed:
		player.velocity.x = Motion.damp(player.velocity.x, target, speed_halflife, delta)


func _push(
		force: float,
		vertical_factor: float,
		lift: float,
		halflife_x: float,
		halflife_y: float,
		delta: float,
) -> void:
	var rotation: float = fludd.body_rotation
	var facing: float = float(player.get_facing())
	player.velocity.x = Motion.drift(
			player.velocity.x,
			cos(rotation) * force * facing,
			Motion.rate(halflife_x),
			delta,
	)
	player.velocity.y = Motion.drift(
			player.velocity.y,
			sin(rotation) * force * vertical_factor - lift,
			Motion.rate(halflife_y),
			delta,
	)
