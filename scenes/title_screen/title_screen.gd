extends Control

@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer
@export var blur_panel: Panel
@export var settings_screen: SettingsScreen

var music: AudioStreamPlaybackInteractive

var _menu_open: bool = false


func _ready() -> void:
	Singleton.set_discord_activity("Staring at the title screen...")
	audio_stream_player.play()
	music = audio_stream_player.get_stream_playback()
	animation_player.play(&"intro")


func _input(event: InputEvent) -> void:
	if _menu_open:
		return
	
	if event is InputEventKey and event.keycode == KEY_1 and event.is_pressed():
		music.switch_to_clip_by_name(&"menu")
		animation_player.play(&"open")
		_menu_open = true


func _on_settings_button_pressed() -> void:
	if not animation_player.is_playing():
		settings_screen.open()
		Singleton.set_discord_activity("Configuring settings...")
		animation_player.play(&"show_settings")
		GDSS.set_state(blur_panel, "open")


func _on_settings_screen_closed() -> void:
	Singleton.set_discord_activity("Staring at title screen, again...")
	animation_player.play(&"hide_settings")
	GDSS.clear_state(blur_panel)


func _on_ld_button_pressed() -> void:
	animation_player.play(&"close")
	Singleton.build_screen_transition()\
		.set_in_duration(0.3)\
		.set_out_duration(0.3)\
		.set_in_texture(preload("uid://34v4s1d3h4ag"))\
		.set_out_texture(preload("uid://34v4s1d3h4ag"))\
		.set_center()\
		.set_destination("uid://b6ofp5p155oy2")\
		.done()
