class_name LDScenario
extends Resource

## A scenario (Mario-Galaxy-style "star"). index 0 is the COMMON baseline; numbered
## scenarios (1..N) store only the layer/tag toggles that differ from COMMON.
## Overrides map an id -> bool; absence means "inherit" (from COMMON, or the all-enabled
## default for COMMON itself). Stored as arrays of [key, value] pairs so they survive both
## binary and JSON serialization (JSON stringifies dictionary keys).


const COMMON_INDEX: int = 0


@export var index: int = 0
## Player-facing name shown on the shine select screen (the editor still lists scenarios by number).
@export var display_name: String = ""
## Whether this scenario shows up as a selectable shine on the shine select screen.
@export var show_in_shine_select: bool = true
## The area this scenario loads at runtime (empty = the level's first area).
@export var area_name: String = ""
@export var layer_overrides: Dictionary[int, bool] = {}
@export var tag_overrides: Dictionary[String, bool] = {}
@export var stamp_overrides: Dictionary[String, bool] = {}
@export var background_override: Dictionary = {}
@export var music_override_enabled: bool = false
@export var music_override: Array = []


func is_common() -> bool:
	return index == COMMON_INDEX


## Pass true/false to force a layer on/off for this scenario, or null to clear (inherit).
func set_layer(layer_index: int, state: Variant) -> void:
	if state == null:
		layer_overrides.erase(layer_index)
	else:
		layer_overrides[layer_index] = bool(state)


func get_layer_override(layer_index: int) -> Variant:
	return layer_overrides.get(layer_index, null)


func set_tag(tag: String, state: Variant) -> void:
	if state == null:
		tag_overrides.erase(tag)
	else:
		tag_overrides[tag] = bool(state)


func get_tag_override(tag: String) -> Variant:
	return tag_overrides.get(tag, null)


func set_stamp(stamp_id: String, state: Variant) -> void:
	if state == null:
		stamp_overrides.erase(stamp_id)
	else:
		stamp_overrides[stamp_id] = bool(state)


func get_stamp_override(stamp_id: String) -> Variant:
	return stamp_overrides.get(stamp_id, null)


func set_background_override(data: Variant) -> void:
	background_override = (data as Dictionary) if data is Dictionary else {}


func get_background_override() -> Variant:
	return background_override if not background_override.is_empty() else null


func set_music_override(layers: Variant) -> void:
	if layers == null:
		music_override_enabled = false
		music_override = []
	else:
		music_override_enabled = true
		music_override = (layers as Array) if layers is Array else []


func get_music_override() -> Variant:
	return music_override if music_override_enabled else null


func serialize() -> Dictionary:
	var layers: Array = []
	for k: int in layer_overrides:
		layers.append([k, layer_overrides[k]])
	var tags: Array = []
	for k: String in tag_overrides:
		tags.append([k, tag_overrides[k]])
	var stamps: Array = []
	for k: String in stamp_overrides:
		stamps.append([k, stamp_overrides[k]])
	return {
		"index": index,
		"display_name": display_name,
		"show_in_shine_select": show_in_shine_select,
		"area_name": area_name,
		"layer_overrides": layers,
		"tag_overrides": tags,
		"stamp_overrides": stamps,
		"background_override": background_override,
		"music_override_enabled": music_override_enabled,
		"music_override": music_override,
	}


static func deserialize(data: Dictionary) -> LDScenario:
	var scenario: LDScenario = LDScenario.new()
	scenario.index = int(data.get("index", 0))
	scenario.display_name = str(data.get("display_name", ""))
	scenario.show_in_shine_select = bool(data.get("show_in_shine_select", true))
	scenario.area_name = str(data.get("area_name", ""))
	for pair: Variant in data.get("layer_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			scenario.layer_overrides[int(pair[0])] = bool(pair[1])
	for pair: Variant in data.get("tag_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			scenario.tag_overrides[str(pair[0])] = bool(pair[1])
	for pair: Variant in data.get("stamp_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			scenario.stamp_overrides[str(pair[0])] = bool(pair[1])
	var bg_override: Variant = data.get("background_override", {})
	scenario.background_override = (bg_override as Dictionary) if bg_override is Dictionary else {}
	scenario.music_override_enabled = bool(data.get("music_override_enabled", false))
	var music_override_data: Variant = data.get("music_override", [])
	scenario.music_override = (music_override_data as Array) if music_override_data is Array else []
	return scenario
