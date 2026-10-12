@tool
extends Node

enum DiscordMode {
	OFF,
	MINIMAL,
	DETAILED,
}

const DISCORD_APP_ID: String = "1496255367607488562"
const SCREEN_TRANSITION: PackedScene = preload("uid://dc1a8llb7l88l")

var _discord: DiscordRichPresence
var _discord_mode: DiscordMode = DiscordMode.OFF
var _discord_timestamps: Dictionary = {"start": int(Time.get_unix_time_from_system())}
var _discord_activity: Dictionary = {}
var _discord_large_image: String = ""
var _commit_hash: String = ""
var _git_branch: String = ""
var _git_fetched: bool = false
var _screen_transition: ScreenTransition


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	
	_screen_transition = SCREEN_TRANSITION.instantiate()
	add_child(_screen_transition)


func build_screen_transition() -> ScreenTransition.Builder:
	return ScreenTransition.Builder.new(_screen_transition)


func is_transitioning() -> bool:
	return _screen_transition.is_transitioning()


func set_screen_transition_visible(visible: bool) -> void:
	_screen_transition.visible = visible


## Returns the current version of the game as a [Version].
func get_version() -> Version:
	_fetch_git()
	return Version.from_string(ProjectSettings.get("application/config/version"), _commit_hash)


func set_discord_mode(mode: DiscordMode) -> void:
	if Engine.is_editor_hint() or mode == _discord_mode:
		return
	_discord_mode = mode
	if mode == DiscordMode.OFF:
		_discord.queue_free()
		_discord = null
		return
	if _discord == null:
		_discord = DiscordRichPresence.new()
		_discord.app_id = DISCORD_APP_ID
		add_child(_discord)
	_push_discord_activity()


func set_discord_activity(details: String = "", state: String = "", large_image: String = "") -> void:
	_discord_activity.clear()
	if not details.is_empty():
		_discord_activity.set("details", details)
	if not state.is_empty():
		_discord_activity.set("state", state)
	_discord_large_image = large_image
	_push_discord_activity()


func _push_discord_activity() -> void:
	if _discord == null:
		return
	var version: Version = get_version()
	var large_image: String = "%s_%s" % [version.major_version, version.minor_version]
	if _discord_mode == DiscordMode.DETAILED and not _discord_large_image.is_empty():
		large_image = _discord_large_image
	var large_text: String = "v%s" % version
	if OS.has_feature("editor") and version.has_hash():
		large_text += " (%s:%s)" % [_git_branch, version.hash()]
	var activity: Dictionary = {
		"timestamps": _discord_timestamps,
		"assets": {"large_image": large_image, "large_text": large_text},
	}
	if _discord_mode == DiscordMode.DETAILED:
		activity.merge(_discord_activity)
	_discord.set_activity(activity)


func _fetch_git() -> void:
	if _git_fetched:
		return
	_git_fetched = true
	_commit_hash = _git(["rev-parse", "--short", "HEAD"])
	_git_branch = _git(["rev-parse", "--abbrev-ref", "HEAD"])


func _git(args: PackedStringArray) -> String:
	var output: Array = []
	if OS.execute("git", PackedStringArray(["-C", ProjectSettings.globalize_path("res://")]) + args, output) != OK or output.is_empty():
		return ""
	return str(output.front()).strip_edges()
