@tool
extends Node


var _discord_handler: DiscordHandler = DiscordHandler.new()
var _input_handler: InputHandler = InputHandler.new()
var _tree_hook: TreeHook = TreeHook.new()


func _init() -> void:
	add_child(_input_handler)
	add_child(_discord_handler)
	add_child(_tree_hook)


func get_version() -> String:
	return ProjectSettings.get_setting("application/config/version")


func get_input_handler() -> InputHandler:
	return _input_handler

## This is a hook which can be used by custom resources to allow syncing
## with the SceneTree process.
func get_tree_hook() -> TreeHook:
	return _tree_hook


func get_discord_handler() -> DiscordHandler:
	return _discord_handler


class InputHandler:
	extends Node
	
	signal input_type_changed
	
	enum InputType {
		KEYBOARD,
		CONTROLLER,
		TOUCH
	}
	
	var _current_input_type: InputType
	
	func _unhandled_input(event: InputEvent) -> void:
		var _old_input_type: InputType = _current_input_type
		
		if event is InputEventKey:
			_current_input_type = InputType.KEYBOARD
		elif event is InputEventJoypadMotion or event is InputEventJoypadButton:
			_current_input_type = InputType.CONTROLLER
		elif event is InputEventScreenTouch or event is InputEventScreenDrag:
			_current_input_type = InputType.TOUCH
		
		if _old_input_type != _current_input_type:
			input_type_changed.emit()
	
	
	func get_current_input_type() -> InputType:
		return _current_input_type
	
	
	func is_using_keyboard() -> bool:
		return _current_input_type == InputType.KEYBOARD
	
	func is_using_controller() -> bool:
		return _current_input_type == InputType.CONTROLLER
	
	func is_using_touch() -> bool:
		return _current_input_type == InputType.TOUCH


class TreeHook:
	extends Node
	
	var _last_delta: float
	var _frame_bound_callables: Dictionary[Callable, Array]
	
	
	func _process(delta: float) -> void:
		for callable: Callable in _frame_bound_callables:
			callable.callv(_frame_bound_callables.get(callable))
		
		_last_delta = delta
	
	
	func get_last_delta() -> float:
		return _last_delta
	
	
	func bind_callable_to_frame(callable: Callable, parameters: Array) -> void:
		_frame_bound_callables.set(callable, parameters)


class DiscordHandler:
	extends Node
	
	const APPLICATION_ID: int = 1496255367607488562
	
	var _client: DiscordClient = DiscordClient.new()
	var _timer: Timer = Timer.new()
	var _is_ready: bool = false
	
	
	func _init() -> void:
		_client.set_application_id(APPLICATION_ID)
		_client.set_status_changed_callback(_on_status_changed)
	
	
	func _ready() -> void:
		add_child(_timer)
		_timer.wait_time = 1.0
		_timer.timeout.connect(_on_timer_timeout)
		_timer.start()
	
	
	func set_presence(details: String = "", state: String = "") -> void:
		var activity: DiscordActivity = _build_activity(details, state)
		activity.set_assets(_build_assets())
		_client.update_rich_presence(activity, _on_presence_updated)
	
	
	func set_presence_with_assets(
		details: String = "",
		state: String = "",
		large_image: String = "",
		large_text: String = "",
		small_image: String = "",
		small_text: String = ""
	) -> void:
		var activity: DiscordActivity = _build_activity(details, state)
		var assets: DiscordActivityAssets = _build_assets(large_image, large_text)
		if not small_image.is_empty():
			assets.set_small_image(small_image)
		if not small_text.is_empty():
			assets.set_small_text(small_text)
		activity.set_assets(assets)
		_client.update_rich_presence(activity, _on_presence_updated)
	
	
	func set_presence_with_party(
		details: String = "",
		state: String = "",
		party_id: String = "",
		current_size: int = 1,
		max_size: int = 1
	) -> void:
		var activity: DiscordActivity = _build_activity(details, state)
		activity.set_assets(_build_assets())
		if not party_id.is_empty():
			var party: DiscordActivityParty = DiscordActivityParty.new()
			party.set_id(party_id)
			party.set_current_size(current_size)
			party.set_max_size(max_size)
			activity.set_party(party)
		_client.update_rich_presence(activity, _on_presence_updated)
	
	
	func clear_presence() -> void:
		_client.update_rich_presence(DiscordActivity.new(), _on_presence_updated)
	
	
	func is_ready() -> bool:
		return _is_ready
	
	
	func _build_activity(details: String = "", state: String = "") -> DiscordActivity:
		var activity: DiscordActivity = DiscordActivity.new()
		activity.set_type(DiscordActivityTypes.PLAYING)
		if not details.is_empty():
			activity.set_details(details)
		if not state.is_empty():
			activity.set_state(state)
		return activity
	
	
	func _build_assets(large_image: String = "icon", large_text: String = "") -> DiscordActivityAssets:
		var assets: DiscordActivityAssets = DiscordActivityAssets.new()
		assets.set_large_image(large_image)
		assets.set_large_text(large_text if not large_text.is_empty() else "v" + Singleton.get_version())
		return assets
	
	
	func _on_timer_timeout() -> void:
		Discord.run_callbacks()
	
	
	func _on_status_changed(status: DiscordClientStatus.Enum, _error: DiscordClientError.Enum, _error_detail: int) -> void:
		_is_ready = status == DiscordClientStatus.READY
	
	
	func _on_presence_updated(_result: DiscordClientResult) -> void:
		pass
