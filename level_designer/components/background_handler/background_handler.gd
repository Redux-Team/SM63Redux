class_name LDBackgroundHandler
extends LDComponent

## Edits the active area's background and renders it into the viewport background root. Each area
## owns its own LDBackground (either one of the LDBackgroundDB presets or a freely edited "Custom"
## copy); editing the backdrop or layers switches that area to Custom. Switching the active area
## rebuilds the view from the new area's background. Reached via LD.get_background_handler().


signal background_changed


const DEFAULT_PRESET: String = "Mushroom Hills"




func _on_ready() -> void:
	background_changed.connect(_persist_session)
	LDLevel._inst.active_area_changed.connect(_on_active_area_changed)
	_rebuild()


func _on_active_area_changed(_area: LDArea) -> void:
	_rebuild()
	background_changed.emit()


## Restores the active area's default background (used when a level is reset).
func reset() -> void:
	LD.get_area().apply_default_background()
	_changed()


func _persist_session() -> void:
	LD.get_save_load_handler().save_session()


## The background currently being edited (the active area's).
func get_background() -> LDBackground:
	return LD.get_area().background


## The curated layer presets the layer picker offers (and uses as add/swap defaults).
func get_available_layers() -> Array[LDBackgroundLayer]:
	return LDBackgroundDB.get_layer_presets()


func get_preset_names() -> Array[String]:
	return LDBackgroundDB.get_preset_names()


func get_active_preset() -> String:
	return LD.get_area().background_preset


func is_custom() -> bool:
	return LD.get_area().background_preset == LDBackgroundDB.CUSTOM


## Applies a preset by name (replacing the active area's background with a fresh copy), or unlocks
## editing when given "Custom" (keeping the current background so the user can tweak from where they
## were).
func select_preset(preset_name: String) -> void:
	var area: LDArea = LD.get_area()
	if preset_name == LDBackgroundDB.CUSTOM:
		if not area.custom_background:
			area.custom_background = area.background.working_copy()
		area.background = area.custom_background
		area.background_preset = LDBackgroundDB.CUSTOM
		_changed()
		return
	var preset: LDBackground = LDBackgroundDB.get_preset(preset_name)
	if not preset:
		return
	area.background = preset.working_copy()
	area.background_preset = preset_name
	_changed()


#region Mutators (custom only)

func set_backdrop_type(type: int) -> void:
	get_background().backdrop_type = type
	_mark_custom()


func set_solid_color(color: Color) -> void:
	get_background().solid_color = color
	_mark_custom()


func set_gradient_top(color: Color) -> void:
	get_background().gradient_top = color
	_mark_custom()


func set_gradient_bottom(color: Color) -> void:
	get_background().gradient_bottom = color
	_mark_custom()


func add_layer() -> void:
	var presets: Array[LDBackgroundLayer] = LDBackgroundDB.get_layer_presets()
	var layer: LDBackgroundLayer = presets[0].duplicate(true) as LDBackgroundLayer if not presets.is_empty() else LDBackgroundLayer.new()
	get_background().layers.append(layer)
	_mark_custom()


## Replaces the layer at `index` with a copy of the given preset (texture + defaults + correct
## anchor), keeping the user's colour styling so swapping textures doesn't lose a tint.
func set_layer_preset(index: int, preset: LDBackgroundLayer) -> void:
	var layers: Array[LDBackgroundLayer] = get_background().layers
	if index < 0 or index >= layers.size() or not preset:
		return
	var current: LDBackgroundLayer = layers[index]
	var fresh: LDBackgroundLayer = preset.duplicate(true) as LDBackgroundLayer
	fresh.modulate = current.modulate
	fresh.custom_color = current.custom_color
	layers[index] = fresh
	_mark_custom()


func remove_layer(index: int) -> void:
	var layers: Array[LDBackgroundLayer] = get_background().layers
	if index < 0 or index >= layers.size():
		return
	layers.remove_at(index)
	_mark_custom()


## Swaps the layer with its neighbour `delta` away, returning the layer's new index.
func move_layer(index: int, delta: int) -> int:
	var layers: Array[LDBackgroundLayer] = get_background().layers
	var target: int = index + delta
	if index < 0 or index >= layers.size() or target < 0 or target >= layers.size():
		return index
	var moved: LDBackgroundLayer = layers[index]
	layers[index] = layers[target]
	layers[target] = moved
	_mark_custom()
	return target


func set_layer_field(index: int, key: String, value: Variant) -> void:
	var layers: Array[LDBackgroundLayer] = get_background().layers
	if index < 0 or index >= layers.size():
		return
	layers[index].set(key, value)
	_mark_custom()

#endregion


#region Serialization

## Serializes one area's background: just the preset name, plus the full data when it's custom.
func serialize_area(area: LDArea) -> Dictionary:
	var data: Dictionary = {"preset": area.background_preset}
	if area.background_preset == LDBackgroundDB.CUSTOM:
		data["data"] = area.background.serialize()
	return data


## Restores an area's background from a saved dict (resolving preset vs custom data).
func apply_to_area(area: LDArea, data: Dictionary) -> void:
	var preset_name: String = str(data.get("preset", ""))
	if preset_name != LDBackgroundDB.CUSTOM and LDBackgroundDB.has_preset(preset_name):
		area.background_preset = preset_name
	else:
		area.background_preset = LDBackgroundDB.CUSTOM
	area.background = LDBackgroundDB.resolve(data)
	if area.background_preset == LDBackgroundDB.CUSTOM:
		area.custom_background = area.background


func serialize() -> Dictionary:
	return serialize_area(LD.get_area())


func deserialize(data: Dictionary) -> void:
	apply_to_area(LD.get_area(), data)
	_rebuild()
	background_changed.emit()

#endregion


## Any edit turns the active area's background into a custom one.
func _mark_custom() -> void:
	var area: LDArea = LD.get_area()
	area.custom_background = area.background
	area.background_preset = LDBackgroundDB.CUSTOM
	_changed()


func _changed() -> void:
	_rebuild()
	background_changed.emit()


func _rebuild() -> void:
	if not is_instance_valid(LD.get_editor_viewport()):
		return
	var area: LDArea = LD.get_area()
	if not area or not area.background:
		return
	var root: Control = LD.get_editor_viewport().get_background_root()
	if root:
		area.background.build_into(root)
