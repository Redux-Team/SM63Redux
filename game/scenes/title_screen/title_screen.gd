class_name TitleScreen
extends Control

@export var title_loop: AudioStreamPlayer
@export var splash_screen: TitleSplashScreen
@export var menu_screen: TitleMenuScreen

@export var version_label: Label
@export var team_label: Label

@export var big_stars: ParticleEmitter
@export var medium_stars: ParticleEmitter
@export var small_stars: ParticleEmitter
@export var shooting_stars: ParticleEmitter

@export var bg: Parallax2D
@export var bg_2: Parallax2D
@export var fg_2: Parallax2D
@export var fg: Parallax2D


var info_labels_shown: bool = false
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
	splash_screen.intro_sequence_done.connect(show_info_labels, CONNECT_ONE_SHOT)
	splash_screen.play_in_animation()
	title_loop.play()
	await splash_screen.animation_player.animation_finished
	splash_screen.play_glow_loop_animation()


# VersionLabel & TeamLabel
func show_info_labels() -> void:
	if info_labels_shown:
		return
	
	var tween: Tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_OUT)
	tween.tween_property(team_label, "offset_top", 0, 0.3)
	tween.tween_property(team_label, "offset_bottom", 0, 0.3)
	tween.tween_property(version_label, "offset_top", 0, 0.3)
	tween.tween_property(version_label, "offset_bottom", 0, 0.3)
	info_labels_shown = true

## Sets the scrolling/animation speed of the title screen background. Also affects particles.
func set_bg_speed(speed: float, time: float = 0.3) -> void:
	var tween: Tween = create_tween()
	tween.tween_property(self, ^"background_speed", speed, time)
