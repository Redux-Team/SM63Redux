class_name PauseScreen
extends CanvasLayer

static var _inst: PauseScreen

@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer
@export var resume_button: Button
@export var slowdown_time: float = 0.15

var _pause_tween: Tween
var _is_open: bool = false
var _level: Level
var _speed: float = 1.0
var _time_scale: float = 1.0
var _physics_ticks: int = 60
var _last_ticks_usec: int = 0


func _enter_tree() -> void:
	visible = false
	_inst = self


func _ready() -> void:
	_level = Level.of(self)
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_last_ticks_usec = Time.get_ticks_usec()
	resume_button.pressed.connect(close)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	animation_player.advance((now - _last_ticks_usec) / 1_000_000.0)
	_last_ticks_usec = now


func _exit_tree() -> void:
	if _pause_tween:
		_pause_tween.kill()
	if _speed < 1.0:
		Engine.time_scale = _time_scale
		Engine.physics_ticks_per_second = _physics_ticks
		_speed = 1.0
	_inst = null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		assert(is_instance_valid(_inst))
		get_viewport().set_input_as_handled()
		if not _is_open:
			open()
		else:
			close()
	elif _is_open and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _unhandled_key_input(_event: InputEvent) -> void:
	if _is_open:
		get_viewport().set_input_as_handled()


func _unhandled_input(_event: InputEvent) -> void:
	if _is_open:
		get_viewport().set_input_as_handled()


func open() -> void:
	if _is_open:
		return
	
	_is_open = true
	if _speed >= 1.0:
		_time_scale = Engine.time_scale
		_physics_ticks = Engine.physics_ticks_per_second
	
	audio_stream_player.play()
	animation_player.play(&"open")
	resume_button.grab_focus()
	_tween_speed(0.0)


func close() -> void:
	if not _is_open:
		return
	
	_is_open = false
	animation_player.play(&"close")
	_tween_speed(1.0)


func _tween_speed(to: float) -> void:
	if _pause_tween:
		_pause_tween.kill()
	
	_pause_tween = create_tween().set_ignore_time_scale()
	_pause_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_pause_tween.tween_method(_set_speed, _speed, to, slowdown_time)


func _set_speed(speed: float) -> void:
	_speed = speed
	var ticks: int = roundi(_physics_ticks * speed)
	var stopped: bool = ticks <= 0
	if stopped:
		Engine.time_scale = 0.0
		Engine.physics_ticks_per_second = _physics_ticks
	else:
		Engine.physics_ticks_per_second = ticks
		Engine.time_scale = _time_scale * ticks / _physics_ticks
	
	if _level and _level.is_world_frozen() != stopped:
		_level.set_world_frozen(stopped)
