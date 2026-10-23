class_name RewindComponent
extends EntityComponent


@export var history_frames: int = 6

var _history: Array[Dictionary] = []
var _tracked: Dictionary[Object, PackedStringArray] = {}


func _ready() -> void:
	Singleton.debug_time.rewind_requested.connect(rewind)


func _physics_process(_delta: float) -> void:
	if not enabled or not entity:
		return
	
	_history.append(_capture())
	while _history.size() > history_frames:
		_history.remove_at(0)


func rewind() -> void:
	if not enabled or _history.size() < 2:
		return
	
	_history.remove_at(_history.size() - 1)
	_apply(_history.back())


func _capture() -> Dictionary:
	var snapshot: Dictionary = {
		"transform": entity.global_transform,
		"velocity": entity.velocity,
		"vars": _capture_vars(entity),
	}
	
	if entity.sprite:
		snapshot["sprite"] = {
			"animation": entity.sprite.current_animation,
			"frame": entity.sprite.current_frame,
			"flip_h": entity.sprite.flip_h,
			"rotation": entity.sprite.rotation_degrees,
		}
	
	if entity.machine:
		var states: Array[Dictionary] = []
		for state: State in entity.machine.get_active_states():
			states.append({
				"name": state.name,
				"time": state.time,
				"frames": state.frames,
				"vars": _capture_vars(state),
			})
		snapshot["machine"] = {
			"current": entity.machine.get_state_name(),
			"states": states,
		}
	
	return snapshot


func _apply(snapshot: Dictionary) -> void:
	entity.global_transform = snapshot["transform"]
	entity.velocity = snapshot["velocity"]
	_apply_vars(entity, snapshot["vars"])
	
	var sprite_data: Dictionary = snapshot.get("sprite", {})
	if entity.sprite and not sprite_data.is_empty():
		entity.sprite.current_animation = sprite_data["animation"]
		entity.sprite.current_frame = sprite_data["frame"]
		entity.sprite.flip_h = sprite_data["flip_h"]
		entity.sprite.rotation_degrees = sprite_data["rotation"]
	
	var machine_data: Dictionary = snapshot.get("machine", {})
	if not entity.machine or machine_data.is_empty():
		return
	
	entity.machine.restore_state(machine_data["current"])
	
	var by_name: Dictionary[StringName, State] = {}
	for active: State in entity.machine.get_active_states():
		by_name[active.name] = active
	
	for entry: Dictionary in machine_data["states"]:
		var state: State = by_name.get(entry["name"])
		if not state:
			continue
		state.time = entry["time"]
		state.frames = entry["frames"]
		_apply_vars(state, entry["vars"])


func _capture_vars(target: Object) -> Dictionary:
	var out: Dictionary = {}
	for prop_name: String in _tracked_props(target):
		var value: Variant = target.get(prop_name)
		if value == null or value is Object:
			continue
		out[prop_name] = value.duplicate() if value is Array or value is Dictionary else value
	return out


func _tracked_props(target: Object) -> PackedStringArray:
	if _tracked.has(target):
		return _tracked[target]
	
	var names: PackedStringArray = []
	for prop: Dictionary in target.get_property_list():
		if int(prop["usage"]) & PROPERTY_USAGE_SCRIPT_VARIABLE:
			names.append(prop["name"])
	
	_tracked[target] = names
	return names


func _apply_vars(target: Object, vars: Dictionary) -> void:
	for key: String in vars:
		target.set(key, vars[key])
