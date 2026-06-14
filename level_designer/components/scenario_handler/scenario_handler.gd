class_name LDScenarioHandler
extends LDComponent

## Owns the level's scenarios: a single COMMON baseline plus numbered scenarios (1..N)
## that override which layers / object groups are enabled. Mirrors LDGroupHandler.


signal scenario_added(scenario: LDScenario)
signal scenario_removed(index: int)
signal scenario_changed(scenario: LDScenario)


var _common: LDScenario
var _scenarios: Dictionary[int, LDScenario] = {}


func _on_ready() -> void:
	_ensure_common()
	scenario_added.connect(_persist_session.unbind(1))
	scenario_removed.connect(_persist_session.unbind(1))
	scenario_changed.connect(_persist_session.unbind(1))


func _ensure_common() -> void:
	if not _common:
		_common = LDScenario.new()
		_common.index = LDScenario.COMMON_INDEX


func get_common() -> LDScenario:
	_ensure_common()
	return _common


func get_scenario(index: int) -> LDScenario:
	if index == LDScenario.COMMON_INDEX:
		return get_common()
	return _scenarios.get(index, null)


func has_scenario(index: int) -> bool:
	return index == LDScenario.COMMON_INDEX or _scenarios.has(index)


## Numbered scenarios sorted by index (COMMON excluded).
func get_numbered_scenarios() -> Array[LDScenario]:
	var keys: Array = _scenarios.keys()
	keys.sort()
	var result: Array[LDScenario] = []
	for k: int in keys:
		result.append(_scenarios[k])
	return result


func create_scenario() -> LDScenario:
	var index: int = 1
	while _scenarios.has(index):
		index += 1
	if index > Level.MAX_SCENARIO_COUNT:
		return null
	var scenario: LDScenario = LDScenario.new()
	scenario.index = index
	_scenarios[index] = scenario
	scenario_added.emit(scenario)
	return scenario


func remove_scenario(index: int) -> void:
	if index == LDScenario.COMMON_INDEX:
		return
	if _scenarios.erase(index):
		scenario_removed.emit(index)


func set_layer_override(index: int, layer_index: int, state: Variant) -> void:
	var scenario: LDScenario = get_scenario(index)
	if not scenario:
		return
	scenario.set_layer(layer_index, state)
	scenario_changed.emit(scenario)


func set_tag_override(index: int, tag: String, state: Variant) -> void:
	var scenario: LDScenario = get_scenario(index)
	if not scenario:
		return
	scenario.set_tag(tag, state)
	scenario_changed.emit(scenario)


## Effective enabled state of a layer under scenario `index`: start all-enabled, apply
## COMMON's override, then (for numbered scenarios) this scenario's own override.
func is_layer_enabled(index: int, layer_index: int) -> bool:
	var enabled: bool = true
	var common_override: Variant = get_common().get_layer_override(layer_index)
	if common_override != null:
		enabled = bool(common_override)
	if index != LDScenario.COMMON_INDEX:
		var scenario: LDScenario = get_scenario(index)
		if scenario:
			var override: Variant = scenario.get_layer_override(layer_index)
			if override != null:
				enabled = bool(override)
	return enabled


func is_tag_enabled(index: int, tag: String) -> bool:
	var enabled: bool = true
	var common_override: Variant = get_common().get_tag_override(tag)
	if common_override != null:
		enabled = bool(common_override)
	if index != LDScenario.COMMON_INDEX:
		var scenario: LDScenario = get_scenario(index)
		if scenario:
			var override: Variant = scenario.get_tag_override(tag)
			if override != null:
				enabled = bool(override)
	return enabled


func serialize_all() -> Dictionary:
	var numbered: Array = []
	for scenario: LDScenario in _scenarios.values():
		numbered.append(scenario.serialize())
	return {
		"common": get_common().serialize(),
		"scenarios": numbered,
	}


func deserialize_all(data: Dictionary) -> void:
	_scenarios.clear()
	_common = LDScenario.deserialize(data.get("common", {}))
	_common.index = LDScenario.COMMON_INDEX
	for entry: Variant in data.get("scenarios", []):
		if not entry is Dictionary:
			continue
		var scenario: LDScenario = LDScenario.deserialize(entry)
		if scenario.index != LDScenario.COMMON_INDEX:
			_scenarios[scenario.index] = scenario


## Editor preview: hides objects on disabled layers / carrying a disabled tag for the
## given scenario, so the effect of COMMON + overrides is visible in the viewport.
func apply_to_editor(index: int) -> void:
	if not is_instance_valid(LD.get_level()):
		return
	var area: LDArea = LDLevel.get_active_area()
	if not area:
		return
	var th: LDTagHandler = LD.get_tag_handler()
	for layer: LDLayer in area.layers:
		var layer_enabled: bool = is_layer_enabled(index, layer.index)
		for child: Node in layer.get_objects_root().get_children():
			var obj: LDObject = child as LDObject
			if not obj:
				continue
			var vis: bool = layer_enabled
			if vis:
				for tag: String in th.get_object_tags(obj):
					if not is_tag_enabled(index, tag):
						vis = false
						break
			obj.visible = vis


## Restores normal editing visibility (everything visible).
func clear_editor_preview() -> void:
	if not is_instance_valid(LD.get_level()):
		return
	var area: LDArea = LDLevel.get_active_area()
	if not area:
		return
	for layer: LDLayer in area.layers:
		for child: Node in layer.get_objects_root().get_children():
			var obj: LDObject = child as LDObject
			if obj:
				obj.visible = true


func _persist_session() -> void:
	LD.get_save_load_handler().save_session()
