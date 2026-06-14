class_name LDScenario
extends Resource

## A scenario (Mario-Galaxy-style "star"). index 0 is the COMMON baseline; numbered
## scenarios (1..N) store only the layer/tag toggles that differ from COMMON.
## Overrides map an id -> bool; absence means "inherit" (from COMMON, or the all-enabled
## default for COMMON itself). Stored as arrays of [key, value] pairs so they survive both
## binary and JSON serialization (JSON stringifies dictionary keys).


const COMMON_INDEX: int = 0


@export var index: int = 0
@export var layer_overrides: Dictionary[int, bool] = {}
@export var tag_overrides: Dictionary[String, bool] = {}
@export var stamp_overrides: Dictionary[String, bool] = {}


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
		"layer_overrides": layers,
		"tag_overrides": tags,
		"stamp_overrides": stamps,
	}


static func deserialize(data: Dictionary) -> LDScenario:
	var scenario: LDScenario = LDScenario.new()
	scenario.index = int(data.get("index", 0))
	for pair: Variant in data.get("layer_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			scenario.layer_overrides[int(pair[0])] = bool(pair[1])
	for pair: Variant in data.get("tag_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			scenario.tag_overrides[str(pair[0])] = bool(pair[1])
	for pair: Variant in data.get("stamp_overrides", []):
		if pair is Array and (pair as Array).size() == 2:
			scenario.stamp_overrides[str(pair[0])] = bool(pair[1])
	return scenario
