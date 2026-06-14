class_name LDArea
extends Node2D


signal layer_created(layer: LDLayer)
signal active_layer_changed(index: int)
signal preview_mode_changed(enabled: bool)


const LAYER_ALPHA_STEP: float = 0.6


static var _inst: LDArea


@export var layers: Array[LDLayer]


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
		if previous.is_empty():
			layers.erase(previous)
			previous.queue_free()
		else:
			previous.is_active = false
	
	var next: LDLayer = get_or_create_layer(index)
	next.is_active = true
	_active_index = index
	refresh_layer_visuals()
	active_layer_changed.emit(index)


## Steps the active layer by a relative amount.
func step_active_layer(delta: int) -> void:
	set_active_layer(_active_index + delta)


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
