extends PlayerState

@export_group("Stroke")
## Upward speed each stroke pulls toward.
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s")
var stroke_speed: float = 142.85
## Time for a stroke to close half the gap to the stroke speed.
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var stroke_halflife: float = 0.0066
## Length of each stroke's upward pull.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var stroke_time: float = 0.175
## Minimum time between strokes.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var stroke_interval: float = 0.2
@export_group("Input")
## How long a swim press stays valid for queuing the next stroke.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var press_buffer: float = 0.12
## Animation restarted on each stroke.
@export var animation: StringName = &"swim"
@export var turbo_animation: StringName = &"swim_fast"

var _stroke_age: float = 0.0
var _queued: bool = false


func _enter() -> void:
	_stroke()


func _tick(delta: float) -> void:
	_stroke_age += delta
	if player.is_swim_pressed(press_buffer):
		_queued = true
		controls.consume(&"jump")
	
	if _queued and _stroke_age >= stroke_interval:
		_stroke()
	
	if overrides_vertical():
		player.velocity.y = minf(
				player.velocity.y,
				Motion.damp(player.velocity.y, -stroke_speed, stroke_halflife, delta),
		)


func _next() -> StringName:
	if _stroke_age < stroke_interval or _is_stroking():
		return &""
	return &"SwimIdle"


func overrides_vertical() -> bool:
	return _stroke_age < stroke_time


func _stroke() -> void:
	_queued = false
	_stroke_age = 0.0
	controls.consume(&"jump")
	sprite.play_at_frame(_get_animation(), 0)


func _is_stroking() -> bool:
	return sprite.playing and sprite.current_animation == _get_animation()


func _get_animation() -> StringName:
	return turbo_animation if player.is_turbo_striking() else animation
