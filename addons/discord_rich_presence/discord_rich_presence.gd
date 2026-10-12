class_name DiscordRichPresence
extends Node
## Discord Rich Presence in pure GDScript. No GDExtension, no Game SDK.
##
## Talks directly to the Discord client over its local IPC channel.
## A frame is [opcode u32][length u32] in little endian, then a JSON body.
## Handshake with your application id (op 0), then SET_ACTIVITY (op 1)
## when the presence changes.
##
## On Windows the channel is a named pipe, opened with FileAccess. On
## macOS and Linux it is a unix socket, which GDScript cannot open, so
## the addon bridges it through the system netcat with
## OS.execute_with_pipe (Godot 4.4+). On any platform where no channel
## is available (web, mobile, headless), this node does nothing.
## Discord not running is not an error either: the client retries alone.
##
## Note: Godot only opens Windows named pipes with the "\\?\pipe\name"
## path form. The usual "\\.\pipe\name" form fails with ERR_FILE_NOT_FOUND.
##
## Usage:
##     var presence := DiscordRichPresence.new()
##     presence.app_id = "1234567890123456789"
##     add_child(presence)
##     presence.set_activity({"details": "In the Hub", "state": "Level 12"})

## Emitted when the handshake completes. [param user] is the Discord user
## object (id, username, ...).
signal presence_connected(user: Dictionary)
## Emitted when the connection drops. The client retries by itself.
signal presence_disconnected

const _OP_HANDSHAKE: int = 0
const _OP_FRAME: int = 1
const _OP_CLOSE: int = 2
const _OP_PING: int = 3
const _OP_PONG: int = 4
## Discord can serve several IPC endpoints (main client, PTB, Canary).
const _MAX_PIPE_INDEX: int = 9
## Delay before looking for Discord again after a failure.
const _RETRY_SECONDS: float = 20.0

## Your Discord application id (from the Developer Portal). Set it before
## add_child, or call connect_now() after changing it.
@export var app_id: String = ""

var _pipe: FileAccess
## Process id of the netcat bridge on macOS and Linux, -1 when unused.
var _bridge_pid: int = -1
## Looking netcat up costs a blocking process launch, and the answer does
## not change while the game runs, so it is searched once and kept.
var _bridge_path: String = ""
var _bridge_searched: bool = false
var _ready_received: bool = false
var _wanted_activity: Dictionary = {}
var _activity_dirty: bool = false
var _retry_left: float = 0.0
var _nonce: int = 0


func _ready() -> void:
	connect_now()


func _exit_tree() -> void:
	_drop()


func _process(delta: float) -> void:
	if _pipe == null:
		_retry_left -= delta
		if _retry_left <= 0.0:
			_retry_left = _RETRY_SECONDS
			_try_connect()
		return
	# A dead bridge means Discord closed the socket (or was never there).
	if _bridge_pid != -1 and not OS.is_process_running(_bridge_pid):
		_drop()
		return
	_poll_frames()
	if _activity_dirty and _ready_received and _pipe:
		_activity_dirty = false
		var args: Dictionary = {"pid": OS.get_process_id()}
		# JSON null clears the presence; an empty object does not.
		args["activity"] = null if _wanted_activity.is_empty() else _wanted_activity
		_send(_OP_FRAME, {"cmd": "SET_ACTIVITY", "args": args, "nonce": str(_nonce)})
		_nonce += 1


## Restart the connection cycle, dropping the current connection if any.
## Safe to call at any time, needed after changing app_id.
func connect_now() -> void:
	_drop()
	_retry_left = 0.0
	set_process(_supported())


## Ask Discord to show [param activity] (the SET_ACTIVITY activity object:
## details, state, timestamps, assets, party, ...). Remembered across
## reconnects, and safe to call while Discord is closed.
func set_activity(activity: Dictionary) -> void:
	_wanted_activity = activity
	_activity_dirty = true


## Remove the presence but keep the connection.
func clear_activity() -> void:
	set_activity({})


func _supported() -> bool:
	if DisplayServer.get_name() == "headless":
		return false
	return OS.get_name() in ["Windows", "macOS", "Linux"]


func _try_connect() -> void:
	if app_id.is_empty():
		return
	if OS.get_name() == "Windows":
		for index: int in _MAX_PIPE_INDEX + 1:
			# Only the "\\?\pipe\" path form works, see the class doc.
			var path: String = "\\\\?\\pipe\\discord-ipc-%d" % index
			var pipe: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
			if pipe == null:
				continue
			_attach(pipe)
			return
		return
	var bridge: String = _find_bridge()
	if bridge.is_empty():
		return
	for path: String in _unix_socket_paths():
		var spawned: Dictionary = OS.execute_with_pipe(bridge, ["-U", path], false)
		if spawned.is_empty():
			continue
		# If nothing listens on the socket, netcat exits at once and the
		# dead-bridge check in _process falls back to the retry cycle.
		_bridge_pid = spawned["pid"]
		_attach(spawned["stdio"])
		return


func _attach(pipe: FileAccess) -> void:
	_pipe = pipe
	_ready_received = false
	_send(_OP_HANDSHAKE, {"v": 1, "client_id": app_id})


## macOS ships nc; on Linux any netcat with unix socket support works.
func _find_bridge() -> String:
	if _bridge_searched:
		return _bridge_path
	_bridge_searched = true
	for name: String in ["nc", "ncat"]:
		var output: Array = []
		if OS.execute("which", [name], output) == 0 and not output.is_empty():
			_bridge_path = str(output[0]).strip_edges()
			if not _bridge_path.is_empty():
				return _bridge_path
	return ""


## Discord puts its socket in the first set directory of this env list,
## or /tmp. Flatpak and snap builds use a subdirectory of the runtime dir.
func _unix_socket_paths() -> PackedStringArray:
	var dirs: PackedStringArray = []
	for env: String in ["XDG_RUNTIME_DIR", "TMPDIR", "TMP", "TEMP"]:
		var value: String = OS.get_environment(env)
		if not value.is_empty():
			dirs.append(value)
			break
	if dirs.is_empty():
		dirs.append("/tmp")
	var runtime: String = OS.get_environment("XDG_RUNTIME_DIR")
	if not runtime.is_empty():
		dirs.append(runtime.path_join("app/com.discordapp.Discord"))
		dirs.append(runtime.path_join("snap.discord"))
	var paths: PackedStringArray = []
	for dir: String in dirs:
		# Sockets are not files for FileAccess.file_exists, but directory
		# listing sees them.
		for file: String in DirAccess.get_files_at(dir):
			if file.begins_with("discord-ipc-"):
				paths.append(dir.path_join(file))
	return paths


func _poll_frames() -> void:
	# FileAccess reads are buffered: the first get_32() reads everything the
	# pipe holds into an internal buffer, and get_length() only sees the OS
	# pipe. So a frame's header and body must be read in the same pass:
	# after the header, a second get_length() check would report 0 while the
	# body sits in the buffer. Discord writes a frame in one write, so when
	# 8 bytes are visible the whole frame is readable.
	while _pipe and _pipe.get_length() >= 8:
		var op: int = _pipe.get_32()
		var length: int = _pipe.get_32()
		var body: Dictionary = {}
		if length > 0:
			var parsed: Variant = JSON.parse_string(
				_pipe.get_buffer(length).get_string_from_utf8())
			if parsed is Dictionary:
				body = parsed
		_handle_frame(op, body)


func _handle_frame(op: int, body: Dictionary) -> void:
	match op:
		_OP_FRAME:
			if str(body.get("evt", "")) == "ERROR":
				# E.g. a present but empty "details": Discord rejects the
				# whole activity. Without this warning the failure is silent.
				push_warning("DiscordRichPresence: Discord refused: %s" % str(
						(body.get("data", {}) as Dictionary).get("message", body)))
			elif not _ready_received and str(body.get("cmd", "")) == "DISPATCH" \
					and str(body.get("evt", "")) == "READY":
				_ready_received = true
				_activity_dirty = true  # Reassert the wanted presence.
				var user: Variant = (body.get("data", {}) as Dictionary).get("user", {})
				presence_connected.emit(user if user is Dictionary else {})
		_OP_PING:
			_send(_OP_PONG, body)
		_OP_CLOSE:
			_drop()


func _send(op: int, body: Dictionary) -> void:
	if _pipe == null:
		return
	var payload: PackedByteArray = JSON.stringify(body).to_utf8_buffer()
	_pipe.store_32(op)  # FileAccess defaults to little endian, the wire order.
	_pipe.store_32(payload.size())
	_pipe.store_buffer(payload)
	_pipe.flush()
	if _pipe.get_error() != OK:
		_drop()


func _drop() -> void:
	if _bridge_pid != -1:
		OS.kill(_bridge_pid)
		_bridge_pid = -1
	_pipe = null
	if _ready_received:
		_ready_received = false
		presence_disconnected.emit()
	_retry_left = _RETRY_SECONDS
