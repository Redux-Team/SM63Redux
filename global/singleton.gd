@tool
extends Node

enum DiscordMode {
	OFF,
	MINIMAL,
	DETAILED,
}

const DISCORD_APP_ID: String = "1496255367607488562"
const SCREEN_TRANSITION: PackedScene = preload("uid://dc1a8llb7l88l")
const TOOLTIP: PackedScene = preload("res://util/ui/tooltip/tooltip.tscn")
const DEBUG_DISPLAY_GROUP: StringName = &"debug_display"

var editor_session: EditorSession = EditorSession.new()
var debug_display_shown: bool = false
var debug_time: DebugTime = DebugTime.new()

var _discord: DiscordRichPresence
var _discord_mode: DiscordMode = DiscordMode.OFF
var _discord_timestamps: Dictionary = {
	"start": int(Time.get_unix_time_from_system()),
}
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
	add_child(TOOLTIP.instantiate())
	add_child(debug_time)
	get_tree().node_added.connect(_on_node_added)


func _input(event: InputEvent) -> void:
	if not Engine.is_editor_hint() and event.is_action_pressed(&"toggle_debug"):
		set_debug_display(not debug_display_shown)


func _exit_tree() -> void:
	editor_session.discard()


func set_debug_display(shown: bool) -> void:
	debug_display_shown = shown and OS.is_debug_build()
	for node: Node in get_tree().get_nodes_in_group(DEBUG_DISPLAY_GROUP):
		_apply_debug_display(node)


func build_screen_transition() -> ScreenTransition.Builder:
	return ScreenTransition.Builder.new(_screen_transition)


func defer_threaded(work: Callable, then: Callable = Callable()) -> bool:
	return _screen_transition.defer_threaded(work, then)


func is_transitioning() -> bool:
	return _screen_transition.is_transitioning()


func set_screen_transition_visible(visible: bool) -> void:
	_screen_transition.visible = visible


func spawn_sibling(
		root_node: Node,
		node: Node,
		shared_properties: PackedStringArray = ["position", "scale"],
) -> void:
	var parent: Node = root_node.get_parent()
	if not is_instance_valid(parent) or not parent.is_inside_tree():
		node.free()
		return
	
	parent.add_child.call_deferred(node)
	parent.move_child.call_deferred(node, root_node.get_index())
	for property: String in shared_properties:
		node.set(property, root_node.get(property))


## Returns the current version of the game as a [Version].
func get_version() -> Version:
	_fetch_git()
	return Version.from_string(ProjectSettings.get(&"application/config/version"), _commit_hash)


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


func set_discord_activity(
		details: String = "",
		state: String = "",
		large_image: String = "",
) -> void:
	_discord_activity.clear()
	if not details.is_empty():
		_discord_activity["details"] = details
	if not state.is_empty():
		_discord_activity["state"] = state
	_discord_large_image = large_image
	_push_discord_activity()


func _on_node_added(node: Node) -> void:
	if node.is_in_group(DEBUG_DISPLAY_GROUP):
		_apply_debug_display(node)


func _apply_debug_display(node: Node) -> void:
	node.process_mode = \
			Node.PROCESS_MODE_INHERIT if debug_display_shown else Node.PROCESS_MODE_DISABLED
	if node is CanvasItem or node is CanvasLayer:
		node.set(&"visible", debug_display_shown)


func _push_discord_activity() -> void:
	if _discord == null:
		return
	var version: Version = get_version()
	var large_image: String = "%s_%s" % [
		version.major_version,
		version.minor_version,
	]
	if _discord_mode == DiscordMode.DETAILED and not _discord_large_image.is_empty():
		large_image = _discord_large_image
	var large_text: String = "v%s" % version
	if OS.has_feature("editor") and version.has_hash():
		large_text += " (%s:%s)" % [_git_branch, version.hash()]
	var activity: Dictionary = {
		"timestamps": _discord_timestamps,
		"assets": { "large_image": large_image, "large_text": large_text },
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
	var repo: String = ProjectSettings.globalize_path("res://")
	if OS.execute("git", PackedStringArray(["-C", repo]) + args, output) != OK or output.is_empty():
		return ""
	return str(output.front()).strip_edges()
