class_name LDTouchSwipeIndicator
extends Node2D


@export var circle_color: Color = Color(1.0, 1.0, 1.0, 0.2)
@export var max_radius: float = 18.0
@export var outer_width: float = 1.0
@export var outer_opacity: float = 0.2

@export_group("Timing")
@export var appear_threshold: float = 0.2
@export var pulse_duration: float = 0.2
@export var dismiss_duration: float = 0.12

@export_group("Pulse")
@export var pulse_peak_opacity: float = 0.6
@export var pulse_settle_opacity: float = 0.15
@export var pulse_ease: Tween.EaseType = Tween.EASE_IN_OUT
@export var pulse_transition: Tween.TransitionType = Tween.TRANS_SINE

@export_group("Dismiss")
@export var dismiss_ease: Tween.EaseType = Tween.EASE_OUT
@export var dismiss_transition: Tween.TransitionType = Tween.TRANS_QUAD


var _tween: Tween
var _fill_radius: float = 0.0
var _outer_alpha: float = 0.0
var _fill_alpha: float = 0.0
var _pulse_alpha: float = 0.0
var _pulsed: bool = false
var _pos: Vector2


func show_at(screen_pos: Vector2) -> void:
	position = screen_pos
	_pos = Vector2.ZERO
	_fill_radius = 0.0
	_outer_alpha = 0.0
	_fill_alpha = 0.0
	_pulse_alpha = 0.0
	_pulsed = false
	if _tween:
		_tween.kill()
	queue_redraw()


func set_progress(progress: float) -> void:
	if progress < appear_threshold:
		_outer_alpha = 0.0
		_fill_alpha = 0.0
		_fill_radius = 0.0
		queue_redraw()
		return
	
	var appear_progress: float = clampf((progress - appear_threshold) / (appear_threshold), 0.0, 1.0)
	_outer_alpha = appear_progress
	
	var fill_progress: float = clampf((progress - appear_threshold) / (1.0 - appear_threshold), 0.0, 1.0)
	_fill_alpha = fill_progress
	_fill_radius = fill_progress * max_radius
	
	if progress >= 1.0 and not _pulsed:
		_pulsed = true
		_start_pulse()
	
	queue_redraw()


func dismiss() -> void:
	_pulsed = false
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(dismiss_ease).set_trans(dismiss_transition)
	_tween.tween_method(_set_outer_alpha, _outer_alpha, 0.0, dismiss_duration)
	_fill_alpha = 0.0
	_fill_radius = 0.0
	_pulse_alpha = 0.0
	queue_redraw()


func _start_pulse() -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.set_ease(pulse_ease).set_trans(pulse_transition)
	_tween.tween_method(_set_pulse, 0.0, pulse_peak_opacity, pulse_duration * 0.5)
	_tween.tween_method(_set_pulse, pulse_peak_opacity, pulse_settle_opacity, pulse_duration * 0.5)


func _set_outer_alpha(a: float) -> void:
	_outer_alpha = a
	queue_redraw()


func _set_pulse(p: float) -> void:
	_pulse_alpha = p
	queue_redraw()


func _draw() -> void:
	if _outer_alpha <= 0.0:
		return
	
	var outer_color: Color = Color(circle_color.r, circle_color.g, circle_color.b, outer_opacity * _outer_alpha)
	draw_arc(_pos, max_radius, 0.0, TAU, 64, outer_color, outer_width)
	
	if _fill_alpha > 0.0 and _fill_radius > 0.0:
		var base_color: Color = Color(circle_color.r, circle_color.g, circle_color.b, circle_color.a * _fill_alpha)
		draw_circle(_pos, _fill_radius, base_color)
		if _pulse_alpha > 0.0:
			var pulse_color: Color = Color(1.0, 1.0, 1.0, _pulse_alpha * _fill_alpha)
			draw_circle(_pos, _fill_radius, pulse_color)
