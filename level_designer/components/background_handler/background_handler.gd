class_name LDBackgroundHandler
extends LDComponent

## Owns the level's live LDBackground, renders it into the viewport background root and persists it.
## A background is either one of the presets in LDBackgroundDB or "Custom" (a freely edited copy);
## editing the backdrop or layers switches it to Custom. Reached via LD.get_background_handler().


signal background_changed


const DEFAULT_PRESET: String = "Mushroom Hills"


## Curated textures the layer picker offers when editing a custom background (set in the scene).
@export var _available_textures: Array[Texture2D] = []


var _background: LDBackground = LDBackground.new()
var _active_preset: String = LDBackgroundDB.CUSTOM
## True once a saved background has been restored, so _on_ready doesn't clobber it with the
## default if the load happened first.
var _restored: bool = false


func _on_ready() -> void:
	if not _restored:
		_apply_default()
	background_changed.connect(_persist_session)
	_rebuild()


func _apply_default() -> void:
	var preset: LDBackground = LDBackgroundDB.get_preset(DEFAULT_PRESET)
	if not preset and not LDBackgroundDB.get_presets().is_empty():
		preset = LDBackgroundDB.get_presets()[0]
	if preset:
		_background = preset.duplicate(true) as LDBackground
		_active_preset = preset.preset_name
	else:
		_background = LDBackground.new()
		_active_preset = LDBackgroundDB.CUSTOM


## Restores the default background (used when a level is reset or loaded without one).
func reset() -> void:
	_apply_default()
	_rebuild()
	background_changed.emit()


func _persist_session() -> void:
	LD.get_save_load_handler().save_session()


func get_background() -> LDBackground:
	return _background


func get_available_textures() -> Array[Texture2D]:
	return _available_textures


func get_preset_names() -> Array[String]:
	return LDBackgroundDB.get_preset_names()


func get_active_preset() -> String:
	return _active_preset


func is_custom() -> bool:
	return _active_preset == LDBackgroundDB.CUSTOM


## Applies a preset by name (replacing the working background with a fresh copy), or unlocks editing
## when given "Custom" (keeping the current background so the user can tweak from where they were).
func select_preset(preset_name: String) -> void:
	if preset_name == LDBackgroundDB.CUSTOM:
		_active_preset = LDBackgroundDB.CUSTOM
		background_changed.emit()
		return
	var preset: LDBackground = LDBackgroundDB.get_preset(preset_name)
	if not preset:
		return
	_background = preset.duplicate(true) as LDBackground
	_active_preset = preset_name
	_changed()


#region Mutators (custom only)

func set_backdrop_type(type: int) -> void:
	_background.backdrop_type = type
	_mark_custom()


func set_solid_color(color: Color) -> void:
	_background.solid_color = color
	_mark_custom()


func set_gradient_top(color: Color) -> void:
	_background.gradient_top = color
	_mark_custom()


func set_gradient_bottom(color: Color) -> void:
	_background.gradient_bottom = color
	_mark_custom()


func add_layer() -> void:
	var layer: LDBackgroundLayer = LDBackgroundLayer.new()
	if not _available_textures.is_empty():
		layer.texture = _available_textures[0]
	_background.layers.append(layer)
	_mark_custom()


func remove_layer(index: int) -> void:
	if index < 0 or index >= _background.layers.size():
		return
	_background.layers.remove_at(index)
	_mark_custom()


## Swaps the layer with its neighbour `delta` away, returning the layer's new index.
func move_layer(index: int, delta: int) -> int:
	var target: int = index + delta
	if index < 0 or index >= _background.layers.size() or target < 0 or target >= _background.layers.size():
		return index
	var moved: LDBackgroundLayer = _background.layers[index]
	_background.layers[index] = _background.layers[target]
	_background.layers[target] = moved
	_mark_custom()
	return target


func set_layer_field(index: int, key: String, value: Variant) -> void:
	if index < 0 or index >= _background.layers.size():
		return
	_background.layers[index].set(key, value)
	_mark_custom()

#endregion


#region Serialization

func serialize() -> Dictionary:
	var data: Dictionary = {"preset": _active_preset}
	if is_custom():
		data["data"] = _background.serialize()
	return data


func deserialize(data: Dictionary) -> void:
	_restored = true
	var preset_name: String = str(data.get("preset", ""))
	if preset_name != LDBackgroundDB.CUSTOM and LDBackgroundDB.has_preset(preset_name):
		_active_preset = preset_name
	else:
		_active_preset = LDBackgroundDB.CUSTOM
	_background = LDBackgroundDB.resolve(data)
	_rebuild()
	background_changed.emit()

#endregion


## Any edit turns the background into a custom one.
func _mark_custom() -> void:
	_active_preset = LDBackgroundDB.CUSTOM
	_changed()


func _changed() -> void:
	_rebuild()
	background_changed.emit()


func _rebuild() -> void:
	if not is_instance_valid(LD.get_editor_viewport()):
		return
	var root: Control = LD.get_editor_viewport().get_background_root()
	if root:
		_background.build_into(root)
