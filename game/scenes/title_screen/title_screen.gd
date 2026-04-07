class_name TitleScreen
extends Control

@export var display_container: Control
@export var fade_out_container: Control
@export var hidden_container: Control

@export var title_loop: AudioStreamPlayer
@export var splash_screen: TitleSplashScreen
@export var menu_screen: TitleMenuScreen

@export var version_label: Label
@export var team_label: Label

@export var big_stars: ParticleEmitter
@export var medium_stars: ParticleEmitter
@export var small_stars: ParticleEmitter
@export var shooting_stars: ParticleEmitter

@export var bg_dim: ColorRect
@export var bg: Parallax2D
@export var bg_2: Parallax2D
@export var fg_2: Parallax2D
@export var fg: Parallax2D

var current_screen: Control
var switching_screen: bool = false
var info_labels_shown: bool = false
var screen_locked: bool = false
var background_speed: float = 1.0:
	set(bs):
		for emitter: ParticleEmitter in [big_stars, medium_stars, small_stars, shooting_stars]:
			emitter.speed_scale = bs
		
		if _parallax_default_speeds.is_empty():
			for parallax: Parallax2D in [bg, bg_2, fg_2, fg]:
				if parallax not in _parallax_default_speeds:
					_parallax_default_speeds.set(parallax, parallax.autoscroll)
		
		for parallax: Parallax2D in [bg, bg_2, fg_2, fg]:
			parallax.autoscroll = _parallax_default_speeds.get(parallax) * bs
		
		background_speed = bs
var _parallax_default_speeds: Dictionary[Parallax2D, Vector2]


func _ready() -> void:
	current_screen = splash_screen
	splash_screen.intro_sequence_done.connect(show_info_labels, CONNECT_ONE_SHOT)
	splash_screen.play_in_animation()
	title_loop.play()
	await splash_screen.animation_player.animation_finished
	splash_screen.play_glow_loop_animation()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not switching_screen:
		match event.keycode:
			KEY_ENTER when current_screen is TitleSplashScreen:
				set_bg_speed(0.5)
				set_bg_dim(0.3)
				switch_screen(menu_screen)
			KEY_ESCAPE when current_screen is TitleMenuScreen:
				set_bg_speed(1.0)
				set_bg_dim(0)
				switch_screen(splash_screen)


# VersionLabel & TeamLabel
func show_info_labels() -> void:
	if info_labels_shown:
		return
	
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_LINEAR).set_ease(Tween.EASE_OUT)
	tween.tween_property(team_label, "offset_top", 0, 0.3)
	tween.tween_property(team_label, "offset_bottom", 0, 0.3)
	tween.tween_property(version_label, "offset_top", 0, 0.3)
	tween.tween_property(version_label, "offset_bottom", 0, 0.3)
	info_labels_shown = true

## Sets the scrolling/animation speed of the title screen background. Also affects particles.
func set_bg_speed(speed: float) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"background_speed", speed, 0.3)


func set_bg_dim(amount: float, time: float = 0.2) -> void:
	var color: Color = Color.BLACK
	color.a = amount
	
	var tween: Tween = create_tween()
	tween.tween_property(bg_dim, ^"color", color, time)


func switch_screen(new_screen: Control) -> void:
	if switching_screen or screen_locked:
		return
	
	switching_screen = true
	
	var old_screen: Control = current_screen
	
	# Old screen 
	fade_out_container.visible = true
	fade_out_container.offset_top = 0
	fade_out_container.offset_bottom = 0
	fade_out_container.modulate = Color.WHITE
	old_screen.reparent(fade_out_container)
	old_screen.offset_top = 0
	old_screen.offset_bottom = 0
	
	# New screen
	display_container.offset_top = 30
	display_container.offset_bottom = 30
	display_container.modulate = Color.TRANSPARENT
	new_screen.reparent(display_container)
	new_screen.offset_top = 0
	new_screen.offset_bottom = 0
	
	# Animate switch
	const ANIMATION_TIME: float = 0.3
	var tween: Tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUINT)
	tween.tween_property(fade_out_container, ^"offset_top", -30, ANIMATION_TIME)
	tween.tween_property(fade_out_container, ^"offset_bottom", -30, ANIMATION_TIME)
	tween.tween_property(fade_out_container, ^"modulate", Color.TRANSPARENT, ANIMATION_TIME)
	
	tween.tween_property(display_container, ^"offset_top", 0, ANIMATION_TIME)
	tween.tween_property(display_container, ^"offset_bottom", 0, ANIMATION_TIME)
	tween.tween_property(display_container, ^"modulate", Color.WHITE, ANIMATION_TIME)
	
	tween.finished.connect(func() -> void:
		old_screen.reparent(hidden_container)
		fade_out_container.hide()
		switching_screen = false
	)
	
	current_screen = new_screen
