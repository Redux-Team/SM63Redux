class_name PauseScreen
extends CanvasLayer

const RESTART_HOLD_TIME: float = 1.0
const RESTART_HOLD_GRACE: float = 0.15
const FADE_TIME: float = 0.12
const EXIT_TEXTS: Dictionary[Level.Context, String] = {
	Level.Context.CAMPAIGN: "Exit",
	Level.Context.PLAYTEST: "Back to LD",
}
const EXIT_CLASSES: Dictionary[Level.Context, String] = {
	Level.Context.CAMPAIGN: "PauseExit",
	Level.Context.PLAYTEST: "PauseExitLD",
}

static var _inst: PauseScreen

@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer
@export var resume_button: Button
@export var retry_button: Button
@export var settings_button: Button
@export var exit_button: Button
@export var panel: PausePanel
@export var button_group: Control
@export var level_info: Control
@export var level_name_label: Label
@export var scenario_name_label: Label
@export var scenario_description_label: Label
@export var level_info_gap: float = 24.0
@export var settings_screen: SettingsScreen
@export var slowdown_time: float = 0.15
@export var expand_time: float = 0.35

var _pause_tween: Tween
var _settings_tween: Tween
var _is_open: bool = false
var _settings_open: bool = false
var _leaving: bool = false
var _level: Level
var _speed: float = 1.0
var _time_scale: float = 1.0
var _last_ticks_usec: int = 0
var _retry_holding: bool = false
var _retry_held: float = 0.0


func _enter_tree() -> void:
	visible = false
	_inst = self


func _ready() -> void:
	_level = Level.of(self)
	animation_player.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	_last_ticks_usec = Time.get_ticks_usec()
	resume_button.pressed.connect(close)
	retry_button.pressed.connect(_on_retry_pressed)
	retry_button.button_down.connect(_on_retry_down)
	retry_button.button_up.connect(_on_retry_up)
	Tooltip.set_text(retry_button, "Hold to restart", Tooltip.Placement.ABOVE)
	settings_button.pressed.connect(open_settings)
	exit_button.pressed.connect(_on_exit_pressed)
	settings_screen.closed.connect(close_settings)
	panel.resized.connect(_fit_level_info)


func _process(_delta: float) -> void:
	var now: int = Time.get_ticks_usec()
	var delta: float = (now - _last_ticks_usec) / 1_000_000.0
	_last_ticks_usec = now
	if animation_player.is_playing():
		animation_player.advance(delta)
	
	if _retry_holding:
		_tick_retry_hold(delta)


func _exit_tree() -> void:
	if _pause_tween:
		_pause_tween.kill()
	if _speed < 1.0:
		Engine.time_scale = _time_scale
		_speed = 1.0
	_inst = null


func _input(event: InputEvent) -> void:
	if _leaving:
		get_viewport().set_input_as_handled()
		return
	
	if _settings_open:
		if event.is_action_pressed(&"pause") or event.is_action_pressed(&"ui_cancel"):
			get_viewport().set_input_as_handled()
			settings_screen.cancel()
		return
	
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
	
	_apply_context()
	_reset_settings()
	audio_stream_player.play()
	animation_player.play(&"open")
	resume_button.grab_focus()
	_tween_speed(0.0)


func close() -> void:
	if not _is_open or _settings_open or _leaving:
		return
	
	_is_open = false
	animation_player.play(&"close")
	_tween_speed(1.0)


func open_settings() -> void:
	if not _is_open or _settings_open or _leaving:
		return
	
	_settings_open = true
	if animation_player.current_animation == &"open":
		animation_player.seek(animation_player.current_animation_length, true)
	settings_screen.open()
	
	_settings_tween = _restart_tween(_settings_tween)
	(
			_settings_tween.tween_property(panel, ^"expansion", 1.0, expand_time)
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	)
	_settings_tween.tween_property(button_group, ^"modulate:a", 0.0, FADE_TIME)
	_settings_tween.tween_property(level_info, ^"modulate:a", 0.0, FADE_TIME)
	_settings_tween.tween_callback(button_group.hide).set_delay(FADE_TIME)
	_settings_tween.tween_callback(settings_screen.show).set_delay(FADE_TIME)
	(
			_settings_tween.tween_property(settings_screen, ^"modulate:a", 1.0, FADE_TIME)
			.from(0.0).set_delay(FADE_TIME)
	)
	_settings_tween.tween_callback(_focus_settings).set_delay(FADE_TIME)


func close_settings() -> void:
	if not _settings_open:
		return
	
	_settings_open = false
	_settings_tween = _restart_tween(_settings_tween)
	_settings_tween.tween_property(settings_screen, ^"modulate:a", 0.0, FADE_TIME)
	_settings_tween.tween_callback(settings_screen.hide).set_delay(FADE_TIME)
	_settings_tween.tween_callback(button_group.show).set_delay(FADE_TIME)
	(
			_settings_tween.tween_property(panel, ^"expansion", 0.0, expand_time)
			.set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT).set_delay(FADE_TIME / 2.0)
	)
	_settings_tween.tween_property(button_group, ^"modulate:a", 1.0, FADE_TIME).set_delay(FADE_TIME)
	_settings_tween.tween_property(level_info, ^"modulate:a", 1.0, FADE_TIME).set_delay(FADE_TIME)
	_settings_tween.tween_callback(settings_button.grab_focus).set_delay(FADE_TIME)


func _on_retry_pressed() -> void:
	if _retry_holding and _retry_held >= RESTART_HOLD_GRACE:
		_cancel_retry_hold()
		return
	
	if _level:
		_leave(_level.request_retry.bind(false))


func _on_retry_down() -> void:
	if _level:
		_retry_holding = true
		_retry_held = 0.0


func _on_retry_up() -> void:
	if _retry_holding:
		_cancel_retry_hold()


func _cancel_retry_hold() -> void:
	_retry_holding = false
	_retry_held = 0.0
	_set_retry_fill(0.0)


func _tick_retry_hold(delta: float) -> void:
	var draw_mode: BaseButton.DrawMode = retry_button.get_draw_mode()
	if draw_mode == BaseButton.DRAW_PRESSED or draw_mode == BaseButton.DRAW_HOVER_PRESSED:
		_retry_held += delta
	else:
		_retry_held = 0.0
	
	_set_retry_fill((_retry_held - RESTART_HOLD_GRACE) / (RESTART_HOLD_TIME - RESTART_HOLD_GRACE))
	if _retry_held >= RESTART_HOLD_TIME:
		_retry_holding = false
		_leave(_level.request_retry.bind(true))


func _set_retry_fill(amount: float) -> void:
	amount = clampf(amount, 0.0, 1.0)
	if GDSS.get_instance_var(retry_button, "hold_progress", 0.0) != amount:
		GDSS.set_instance_var(retry_button, "hold_progress", amount)


func _on_exit_pressed() -> void:
	if _level:
		_leave(_level.request_exit)


func _leave(request: Callable) -> void:
	if _leaving:
		return
	
	_leaving = true
	request.call()
	if not Singleton.is_transitioning():
		_leaving = false


func _apply_context() -> void:
	var context: Level.Context = _level.context if _level else Level.Context.CAMPAIGN
	exit_button.text = EXIT_TEXTS.get(context, EXIT_TEXTS[Level.Context.CAMPAIGN])
	GDSS.set_classes(exit_button, [EXIT_CLASSES.get(context, EXIT_CLASSES[Level.Context.CAMPAIGN])])
	retry_button.disabled = not (_level and _level.can_retry())
	exit_button.disabled = not (_level and _level.can_exit())
	
	level_name_label.text = _level.get_level_name() if _level else ""
	scenario_name_label.text = _level.get_scenario_name() if _level else ""
	var description: String = _level.get_scenario_description() if _level else ""
	scenario_description_label.text = "\"%s\"" % description if description else ""


func _fit_level_info() -> void:
	if panel.expansion > 0.0:
		return
	
	level_info.offset_right = -(panel.size.x + level_info_gap)


func _reset_settings() -> void:
	if _settings_tween:
		_settings_tween.kill()
	_settings_open = false
	panel.expansion = 0.0
	button_group.show()
	settings_screen.hide()
	settings_screen.modulate.a = 0.0


func _focus_settings() -> void:
	var categories: Container = settings_screen.category_container
	if categories.get_child_count() > 0:
		(categories.get_child(0) as Control).grab_focus()


func _restart_tween(tween: Tween) -> Tween:
	if tween:
		tween.kill()
	return create_tween().set_ignore_time_scale().set_parallel()


func _tween_speed(to: float) -> void:
	if _pause_tween:
		_pause_tween.kill()
	
	_pause_tween = create_tween().set_ignore_time_scale()
	_pause_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_pause_tween.tween_method(_set_speed, _speed, to, slowdown_time)


func _set_speed(speed: float) -> void:
	_speed = speed
	var stopped: bool = speed <= 0.0
	Engine.time_scale = _time_scale * speed
	if _level and _level.is_world_frozen() != stopped:
		_level.set_world_frozen(stopped)
