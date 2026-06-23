class_name LDArea
extends Node2D


signal layer_created(layer: LDLayer)
signal active_layer_changed(index: int)
signal layers_changed
signal preview_mode_changed(enabled: bool)


const LAYER_ALPHA_STEP: float = 0.6


static var _inst: LDArea


@export var layers: Array[LDLayer]


## Player-facing name shown in the Areas list and used to link scenarios to this area.
var area_name: String = ""
## This area's own background (each area renders its own backdrop + parallax layers).
var background: LDBackground
## Preset name driving the background, or LDBackgroundDB.CUSTOM once it has been edited.
var background_preset: String = ""
## The area's preserved freely-edited background, stashed aside so switching to a preset and back to
## Custom restores the earlier edits. Only the active `background` is rendered and serialized.
var custom_background: LDBackground = null
var music: LDMusic = null
## Preset name driving the music, or LDMusicPresetDB.CUSTOM once it has been edited.
var music_preset: String = ""
## The area's preserved freely-edited music, stashed aside so switching to a preset and back to
## Custom restores the earlier edits.
var custom_music: LDMusic = null
## Per-area editor view: each area pans/zooms independently, like a separate level. Stripped on
## export, so it only matters in the editor.
var camera_position: Vector2 = Vector2.ZERO
var camera_zoom: Vector2 = Vector2.ONE

var _active_index: int = 0
var _preview_mode: bool = false
var _hidden_layers: Dictionary[int, bool] = {}
var _background_root: Node2D


func _init() -> void:
	_inst = self
	_background_root = Node2D.new()
	_background_root.name = "Background"
	add_child(_background_root)
	move_child(_background_root, 0)


## Returns the currently active layer, creating it if it does not exist.
func get_active_layer() -> LDLayer:
	return get_or_create_layer(_active_index)


## Returns the currently active layer index, creating the layer it does not exist.
func get_active_layer_index() -> int:
	return get_active_layer().index


## Sets the active layer by index, deactivating and cleaning up the previous one if empty.
func set_active_layer(index: int) -> void:
	var previous: LDLayer = null
	for layer: LDLayer in layers:
		if layer.index == _active_index:
			previous = layer
			break
	
	if previous:
		previous.is_active = false

	var next: LDLayer = get_or_create_layer(index)
	next.is_active = true
	_active_index = index
	refresh_layer_visuals()
	active_layer_changed.emit(index)


## Steps the active layer by a relative amount.
func step_active_layer(delta: int) -> void:
	set_active_layer(_active_index + delta)


## Renames a layer, notifying listeners (e.g. the toolbar's active-layer label).
func set_layer_name(layer: LDLayer, layer_name: String) -> void:
	layer.layer_name = layer_name
	layers_changed.emit()


## Creates a fresh layer above the current topmost one and makes it active.
func add_layer() -> LDLayer:
	var top_index: int = 0
	for layer: LDLayer in layers:
		top_index = maxi(top_index, layer.index + 1)
	var layer: LDLayer = get_or_create_layer(top_index)
	set_active_layer(top_index)
	return layer


## Inserts a fresh layer directly below `reference` (shifting the layers above it up) and makes it
## active.
func add_layer_below(reference: LDLayer) -> LDLayer:
	return _insert_layer(reference.index + 1)


## Inserts a fresh layer directly above `reference` (shifting it and the layers above up) and makes
## it active.
func add_layer_above(reference: LDLayer) -> LDLayer:
	return _insert_layer(reference.index)


func _insert_layer(at_index: int) -> LDLayer:
	for layer: LDLayer in layers:
		if layer.index >= at_index:
			layer.index += 1
	var layer: LDLayer = get_or_create_layer(at_index)
	_reorder_children()
	set_active_layer(at_index)
	layers_changed.emit()
	return layer


## Removes a layer (and any objects on it), picking a new active layer if needed.
func remove_layer(layer: LDLayer) -> void:
	if not layers.has(layer):
		return
	var was_active: bool = layer.index == _active_index
	layers.erase(layer)
	layer.queue_free()
	if was_active:
		_active_index = layers[0].index if not layers.is_empty() else 0
		if not layers.is_empty():
			layers[0].is_active = true
	refresh_layer_visuals()
	layers_changed.emit()
	active_layer_changed.emit(_active_index)


## Swaps a layer's render depth with its neighbour `delta` away (its objects move with it).
func move_layer_order(layer: LDLayer, delta: int) -> void:
	var pos: int = layers.find(layer)
	var target: int = pos + delta
	if pos < 0 or target < 0 or target >= layers.size():
		return
	var other: LDLayer = layers[target]
	var active_layer: LDLayer = null
	for candidate: LDLayer in layers:
		if candidate.index == _active_index:
			active_layer = candidate
			break

	var swapped_index: int = layer.index
	layer.index = other.index
	other.index = swapped_index
	_reorder_children()

	if active_layer:
		_active_index = active_layer.index
	refresh_layer_visuals()
	layers_changed.emit()
	active_layer_changed.emit(_active_index)


## Sorts layers by index and matches the scene-tree order so the CanvasGroups render in order.
func _reorder_children() -> void:
	layers.sort_custom(func(a: LDLayer, b: LDLayer) -> bool:
		return a.index < b.index
	)
	for i: int in layers.size():
		move_child(layers[i], _background_root.get_index() + 1 + i)


## Gives this area a fresh copy of the default background preset (used for new/blank areas).
func apply_default_background() -> void:
	var preset: LDBackground = LDBackgroundDB.get_preset(LDBackgroundHandler.DEFAULT_PRESET)
	if not preset and not LDBackgroundDB.get_presets().is_empty():
		preset = LDBackgroundDB.get_presets()[0]
	if preset:
		background = preset.working_copy()
		background_preset = preset.preset_name
	else:
		background = LDBackground.new()
		background_preset = LDBackgroundDB.CUSTOM


func apply_default_music() -> void:
	music = LDMusic.new()
	music_preset = LDMusicPresetDB.CUSTOM
	custom_music = music


## Saves the current editor viewport view into this area (called when leaving it).
func store_view() -> void:
	var viewport: LDViewport = LD.get_editor_viewport()
	if not is_instance_valid(viewport):
		return
	camera_position = viewport.camera_position
	camera_zoom = viewport.camera_zoom


## Applies this area's saved view to the editor viewport (called when entering it).
func restore_view() -> void:
	var viewport: LDViewport = LD.get_editor_viewport()
	if not is_instance_valid(viewport):
		return
	viewport.camera_position = camera_position
	viewport.camera_zoom = camera_zoom


## Sets the background of this area into the given root, replacing any existing background.
func set_background(root: Node2D, node: Node) -> void:
	for child: Node in root.get_children():
		child.queue_free()
	root.add_child(node)


## Returns the layer at the given index, creating and inserting it in sorted order if it does not exist.
func get_or_create_layer(index: int) -> LDLayer:
	for layer: LDLayer in layers:
		if layer.index == index:
			return layer
	
	var new_layer: LDLayer = LDLayer.new()
	new_layer.index = index
	new_layer.is_parallaxing = LD.get_ui().get_viewport_handler().is_parallaxing_enabled()
	new_layer.set_modulating(LD.get_ui().get_viewport_handler().is_modulation_enabled())
	add_child(new_layer)
	
	var insert_pos: int = 0
	for i: int in layers.size():
		if layers.get(i).index < index:
			insert_pos = i + 1
	
	move_child(new_layer, insert_pos)
	layers.append(new_layer)
	layers.sort_custom(func(a: LDLayer, b: LDLayer) -> bool:
		return a.index < b.index
	)
	
	layer_created.emit(new_layer)
	return new_layer


## Returns all objects across every layer in this area.
func get_all_objects() -> Array[LDObject]:
	var result: Array[LDObject] = []
	for layer: LDLayer in layers:
		for child: Node in layer.get_objects_root().get_children():
			var obj: LDObject = child as LDObject
			if obj:
				result.append(obj)
	return result


## Returns all objects on the layer at the given index.
func get_all_objects_on_layer(index: int = _active_index) -> Array[LDObject]:
	var result: Array[LDObject] = []
	for layer: LDLayer in layers:
		if layer.index != index:
			continue
		for child: Node in layer.get_objects_root().get_children():
			var obj: LDObject = child as LDObject
			if obj:
				result.append(obj)
	return result


## Finds and returns the first object matching the given source ID on the specified layer.
func find_object_by_id(id: String, index: int = _active_index) -> LDObject:
	for obj: LDObject in get_all_objects_on_layer(index):
		if obj.source_object_id == id:
			return obj
	return null


## Index of the layer the player is on. Layer numbering is shown relative to this so the
## player's layer reads as "Layer 0". Falls back to 0 when no player has been placed.
func get_player_layer_index() -> int:
	for layer: LDLayer in layers:
		for child: Node in layer.get_objects_root().get_children():
			var obj: LDObject = child as LDObject
			if obj and obj.source_object_id == "player_mario":
				return layer.index
	return 0


## Adds an object to the layer at the given index, defaulting to the active layer.
func add_object(object: LDObject, pos: Vector2i = Vector2i.ZERO, index: int = _active_index) -> void:
	var layer: LDLayer = get_or_create_layer(index)
	layer.get_objects_root().add_child(object)
	object.position = pos
	_apply_layer_visual(layer)


## Moves an object to the layer at the given index.
func move_object_to_layer(object: LDObject, index: int) -> void:
	object.reparent(get_or_create_layer(index).get_objects_root())


## Moves an array of objects to the layer at the given index.
func move_objects_to_layer(objects: Array[LDObject], index: int) -> void:
	var root: Node2D = get_or_create_layer(index).get_objects_root()
	for obj: LDObject in objects:
		var game_object: GameObject = GameDB.get_db().find_game_object(obj.source_object_id)
		if game_object.ld_flags & GameObject.LD_LAYERABLE:
			obj.reparent(root)


## Returns whether the layer at the given index is visible.
func is_layer_visible(index: int) -> bool:
	if _preview_mode:
		return true
	return not _hidden_layers.get(index, false)


## Returns whether the layer at the given index is selectable.
func is_layer_selectable(index: int) -> bool:
	if _preview_mode:
		return true
	return index == _active_index


## Sets the visibility of the layer at the given index.
@warning_ignore("shadowed_variable_base_class")
func set_layer_visible(index: int, is_visible: bool) -> void:
	if is_visible:
		_hidden_layers.erase(index)
	else:
		_hidden_layers[index] = true
	refresh_layer_visuals()


## Toggles the visibility of the layer at the given index.
func toggle_layer_visible(index: int) -> void:
	set_layer_visible(index, not is_layer_visible(index))


## Enables or disables preview mode, which makes all layers fully visible and selectable.
func set_preview_mode(enabled: bool) -> void:
	_preview_mode = enabled
	refresh_layer_visuals()
	preview_mode_changed.emit(enabled)


## Toggles preview mode.
func toggle_preview_mode() -> void:
	set_preview_mode(not _preview_mode)


func refresh_layer_visuals() -> void:
	for layer: LDLayer in layers:
		_apply_layer_visual(layer)


func _apply_layer_visual(layer: LDLayer) -> void:
	if not LD.get_ui().get_viewport_handler().is_ghosting_enabled():
		layer.visible = true
		layer._internal_modulation = Color.WHITE
		return
	
	if _hidden_layers.get(layer.index, false):
		layer.visible = false
		return
	
	layer.visible = true
	var distance: int = layer.index - _active_index
	var alpha: float = clampf(1.0 - absi(distance) * LAYER_ALPHA_STEP, 0.0, 1.0)
	layer._internal_modulation = Color(0.05, 0.05, 0.05, alpha) \
		if distance < 0 else Color(1.0, 1.0, 1.0, alpha)
