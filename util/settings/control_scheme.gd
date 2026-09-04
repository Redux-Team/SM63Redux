class_name ControlScheme

## Rebindable input, layered over the project's [InputMap]. The bindings in project.godot stay
## the single source of truth for defaults: they are snapshotted on first use, and a player's
## overrides are stored through [Settings] as compact event strings, so resetting is just
## dropping the override.


const KEY_PREFIX: String = "k"
const BUTTON_PREFIX: String = "b"
const AXIS_PREFIX: String = "a"
const MOUSE_PREFIX: String = "m"
## Beyond this an action stops accepting new bindings, so one action cannot swallow the pad.
const MAX_EVENTS: int = 4

## The actions offered for rebinding, in the order the Controls tab lists them. Engine ui_*
## actions are deliberately absent: they are what makes the menus navigable, so letting them be
## unbound would let a player lock themselves out.
const ACTIONS: Array[StringName] = [
	&"move_left",
	&"move_right",
	&"jump",
	&"crouch",
	&"dive",
	&"spin",
	&"ground_pound",
	&"swim_down",
	&"use_fludd",
	&"switch_fludd_nozzle",
	&"camera_zoom_in",
	&"camera_zoom_out",
]

const ACTION_LABELS: Dictionary[StringName, String] = {
	&"move_left": "Move Left",
	&"move_right": "Move Right",
	&"jump": "Jump",
	&"crouch": "Crouch",
	&"dive": "Dive",
	&"spin": "Spin",
	&"ground_pound": "Ground Pound",
	&"swim_down": "Swim Down",
	&"use_fludd": "Use FLUDD",
	&"switch_fludd_nozzle": "Switch Nozzle",
	&"camera_zoom_in": "Zoom In",
	&"camera_zoom_out": "Zoom Out",
}

const BUTTON_LABELS: Dictionary[int, String] = {
	JOY_BUTTON_A: "A",
	JOY_BUTTON_B: "B",
	JOY_BUTTON_X: "X",
	JOY_BUTTON_Y: "Y",
	JOY_BUTTON_BACK: "Select",
	JOY_BUTTON_GUIDE: "Guide",
	JOY_BUTTON_START: "Start",
	JOY_BUTTON_LEFT_STICK: "L3",
	JOY_BUTTON_RIGHT_STICK: "R3",
	JOY_BUTTON_LEFT_SHOULDER: "LB",
	JOY_BUTTON_RIGHT_SHOULDER: "RB",
	JOY_BUTTON_DPAD_UP: "D-Pad Up",
	JOY_BUTTON_DPAD_DOWN: "D-Pad Down",
	JOY_BUTTON_DPAD_LEFT: "D-Pad Left",
	JOY_BUTTON_DPAD_RIGHT: "D-Pad Right",
}

const AXIS_LABELS: Dictionary[int, String] = {
	JOY_AXIS_LEFT_X: "Left Stick",
	JOY_AXIS_LEFT_Y: "Left Stick",
	JOY_AXIS_RIGHT_X: "Right Stick",
	JOY_AXIS_RIGHT_Y: "Right Stick",
	JOY_AXIS_TRIGGER_LEFT: "LT",
	JOY_AXIS_TRIGGER_RIGHT: "RT",
}

const MOUSE_LABELS: Dictionary[int, String] = {
	MOUSE_BUTTON_LEFT: "Left Click",
	MOUSE_BUTTON_RIGHT: "Right Click",
	MOUSE_BUTTON_MIDDLE: "Middle Click",
	MOUSE_BUTTON_WHEEL_UP: "Wheel Up",
	MOUSE_BUTTON_WHEEL_DOWN: "Wheel Down",
}


static var _defaults: Dictionary[StringName, PackedStringArray] = {}
static var _captured: bool = false


static func _capture_defaults() -> void:
	if _captured:
		return
	_captured = true
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			_defaults.set(action, serialize_events(InputMap.action_get_events(action)))


## Settings key holding [param action]'s override, e.g. &"controls/jump".
static func get_key(action: StringName) -> StringName:
	return StringName("controls/%s" % action)


static func get_label(action: StringName) -> String:
	return ACTION_LABELS.get(action, String(action).capitalize())


static func get_default_events(action: StringName) -> PackedStringArray:
	_capture_defaults()
	return _defaults.get(action, PackedStringArray())


## The action's current bindings, as live [InputEvent]s. Actions outside [constant ACTIONS] are
## not rebindable and have no stored override, so they are read straight from the [InputMap] -
## that way input hints can be shown for engine actions like ui_accept too.
static func get_events(action: StringName) -> Array[InputEvent]:
	if not Settings.has(get_key(action)):
		var events: Array[InputEvent] = []
		if InputMap.has_action(action):
			events.assign(InputMap.action_get_events(action))
		return events
	
	return deserialize_events(Settings.get_value(get_key(action)) as PackedStringArray)


static func set_events(action: StringName, events: Array[InputEvent]) -> void:
	Settings.set_value(get_key(action), serialize_events(events))
	refresh(action)


## Adds [param event] to [param action]. Returns false when the action is full or already
## carries an equivalent binding.
static func add_event(action: StringName, event: InputEvent) -> bool:
	var events: Array[InputEvent] = get_events(action)
	if events.size() >= MAX_EVENTS:
		return false
	for existing: InputEvent in events:
		if existing.is_match(event, true):
			return false
	
	events.append(event)
	set_events(action, events)
	return true


static func remove_event(action: StringName, event: InputEvent) -> void:
	var kept: Array[InputEvent] = []
	for existing: InputEvent in get_events(action):
		if not existing.is_match(event, true):
			kept.append(existing)
	set_events(action, kept)


static func clear(action: StringName) -> void:
	set_events(action, [] as Array[InputEvent])


static func reset(action: StringName) -> void:
	Settings.set_value(get_key(action), get_default_events(action))
	refresh(action)


static func reset_all() -> void:
	for action: StringName in ACTIONS:
		reset(action)


## Other rebindable actions that [param event] would also trigger. The Controls tab warns with
## this rather than refusing the bind, since sharing a key is sometimes deliberate.
static func find_conflicts(action: StringName, event: InputEvent) -> Array[StringName]:
	var conflicts: Array[StringName] = []
	for other: StringName in ACTIONS:
		if other == action:
			continue
		for existing: InputEvent in get_events(other):
			if existing.is_match(event, true):
				conflicts.append(other)
				break
	return conflicts


## True for events worth binding to a gameplay action: keyboard keys and pad input, filtered for
## key echoes and stick noise below the deadzone. Mouse buttons are deliberately excluded - the
## click that starts a rebind would otherwise bind itself.
static func is_bindable(event: InputEvent) -> bool:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	if event is InputEventJoypadMotion:
		return absf((event as InputEventJoypadMotion).axis_value) >= 0.5
	return false


#region Serialization

static func serialize_events(events: Array) -> PackedStringArray:
	var result: PackedStringArray = PackedStringArray()
	for event: InputEvent in events:
		var text: String = serialize_event(event)
		if not text.is_empty():
			result.append(text)
	return result


static func serialize_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		var code: int = key.physical_keycode if key.physical_keycode != KEY_NONE else key.keycode
		return "%s:%d" % [KEY_PREFIX, code]
	if event is InputEventJoypadButton:
		return "%s:%d" % [BUTTON_PREFIX, (event as InputEventJoypadButton).button_index]
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		return "%s:%d:%d" % [AXIS_PREFIX, motion.axis, signi(roundi(motion.axis_value))]
	if event is InputEventMouseButton:
		return "%s:%d" % [MOUSE_PREFIX, (event as InputEventMouseButton).button_index]
	return ""


static func deserialize_events(texts: PackedStringArray) -> Array[InputEvent]:
	var result: Array[InputEvent] = []
	for text: String in texts:
		var event: InputEvent = deserialize_event(text)
		if event:
			result.append(event)
	return result


static func deserialize_event(text: String) -> InputEvent:
	var parts: PackedStringArray = text.split(":")
	if parts.size() < 2:
		return null
	
	match parts.get(0):
		KEY_PREFIX:
			var key: InputEventKey = InputEventKey.new()
			key.physical_keycode = int(parts.get(1)) as Key
			return key
		BUTTON_PREFIX:
			var button: InputEventJoypadButton = InputEventJoypadButton.new()
			button.button_index = int(parts.get(1)) as JoyButton
			button.pressed = true
			return button
		AXIS_PREFIX:
			if parts.size() < 3:
				return null
			var motion: InputEventJoypadMotion = InputEventJoypadMotion.new()
			motion.axis = int(parts.get(1)) as JoyAxis
			motion.axis_value = signf(float(parts.get(2)))
			return motion
		MOUSE_PREFIX:
			var mouse: InputEventMouseButton = InputEventMouseButton.new()
			mouse.button_index = int(parts.get(1)) as MouseButton
			mouse.pressed = true
			return mouse
	return null

#endregion


## Short label for one binding, e.g. "Space", "A", "Left Stick Left".
static func describe_event(event: InputEvent) -> String:
	if event is InputEventKey:
		var key: InputEventKey = event as InputEventKey
		if key.physical_keycode == KEY_NONE:
			return OS.get_keycode_string(key.keycode)
		# Physical codes are positions, so they are resolved through the active layout to name
		# the key the player actually has in front of them. The dummy display server cannot.
		if DisplayServer.get_name() == "headless":
			return OS.get_keycode_string(key.physical_keycode)
		return OS.get_keycode_string(DisplayServer.keyboard_get_keycode_from_physical(key.physical_keycode))
	if event is InputEventJoypadButton:
		var index: int = (event as InputEventJoypadButton).button_index
		return BUTTON_LABELS.get(index, "Button %d" % index)
	if event is InputEventJoypadMotion:
		var motion: InputEventJoypadMotion = event as InputEventJoypadMotion
		var axis_name: String = AXIS_LABELS.get(motion.axis, "Axis %d" % motion.axis)
		if motion.axis == JOY_AXIS_TRIGGER_LEFT or motion.axis == JOY_AXIS_TRIGGER_RIGHT:
			return axis_name
		var horizontal: bool = motion.axis == JOY_AXIS_LEFT_X or motion.axis == JOY_AXIS_RIGHT_X
		var positive: bool = motion.axis_value > 0.0
		var direction: String
		if horizontal:
			direction = "Right" if positive else "Left"
		else:
			direction = "Down" if positive else "Up"
		return "%s %s" % [axis_name, direction]
	if event is InputEventMouseButton:
		var button: int = (event as InputEventMouseButton).button_index
		return MOUSE_LABELS.get(button, "Mouse %d" % button)
	return "?"


## The single binding to show the player for [param action], picked to match whatever they are
## currently playing with, so a hint reads "Enter" on a keyboard and the pad button on a
## controller. Empty when the action has nothing bound for that device.
static func describe_for_current_device(action: StringName) -> String:
	var controller: bool = Singleton.get_input_handler().is_using_controller()
	var fallback: String = ""
	
	for event: InputEvent in get_events(action):
		var pad: bool = event is InputEventJoypadButton or event is InputEventJoypadMotion
		if pad == controller:
			return describe_event(event)
		if fallback.is_empty():
			fallback = describe_event(event)
	
	return fallback


## Comma-joined bindings for an action, or "Unbound" when it has none.
static func describe_action(action: StringName) -> String:
	var parts: PackedStringArray = PackedStringArray()
	for event: InputEvent in get_events(action):
		parts.append(describe_event(event))
	return "Unbound" if parts.is_empty() else ", ".join(parts)


## Rewrites the action in the live [InputMap] from its stored bindings. Each keybind setting's
## applier calls this, so startup and every later rebind take the same path.
static func refresh(action: StringName) -> void:
	if not InputMap.has_action(action):
		return
	
	InputMap.action_erase_events(action)
	for event: InputEvent in get_events(action):
		InputMap.action_add_event(action, event)


## Applies the stick deadzone to every rebindable action.
static func apply_deadzone(value: float) -> void:
	for action: StringName in ACTIONS:
		if InputMap.has_action(action):
			InputMap.action_set_deadzone(action, value)
