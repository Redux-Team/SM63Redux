class_name LDLevelHandler
extends LDHandler

signal level_opened
signal area_changed(area: LevelArea)
signal layer_changed(layer: LevelLayer)
signal structure_changed

const LAYER_PROPERTIES: Array[StringName] = [&"layer_name", &"distance", &"modulation", &"is_decoration"]

@export var ghost_tint: Color = Color(1.0, 1.0, 1.0, 0.35)
@export var pulse_tint: Color = Color(1.0, 1.0, 1.0, 0.4)
@export var fade_duration: float = 0.25
@export var depth_duration: float = 0.2

var areas: Array[LevelArea] = []
var active_area: LevelArea
var active_layer: LevelLayer
var level_name: String = ""
var extras: Dictionary = {}
var editor_state: Dictionary = {}
var focus_enabled: bool = false:
	set(value):
		focus_enabled = value
		refresh_layer_visuals(true)
var modulation_enabled: bool = true:
	set(value):
		modulation_enabled = value
		refresh_layer_visuals()

var _visual_tween: Tween
var _focus_distance: float = 0.0


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		_free_detached_areas()


func _unhandled_input(event: InputEvent) -> void:
	if editor.is_shortcut(event, &"ld_layer_up"):
		step_layer(1)
	elif editor.is_shortcut(event, &"ld_layer_down"):
		step_layer(-1)
	else:
		return
	
	get_viewport().set_input_as_handled()


func new_level() -> void:
	open(LevelData.create())


func open(data: LevelData) -> void:
	editor.history_handler.clear()
	if active_area:
		editor.world.remove_child(active_area)
	_free_detached_areas()
	areas.clear()
	active_area = null
	active_layer = null
	level_name = data.level_name
	extras = data.extras
	editor_state = data.editor.duplicate(true)
	for area_data: AreaData in data.areas:
		areas.append(LevelArea.build(area_data, GameObject.Context.EDITOR))
	
	var active_index: int = data.editor.get("active_area", 0)
	set_active_area(areas.get(clampi(active_index, 0, areas.size() - 1)))
	level_opened.emit()


func capture() -> LevelData:
	editor.viewport_handler.store_view(active_area)
	var data: LevelData = LevelData.new()
	data.level_name = level_name
	data.extras = extras
	data.editor = editor_state.duplicate(true)
	data.editor.set("active_area", areas.find(active_area))
	for area: LevelArea in areas:
		data.areas.append(area.capture())
	
	return data


func set_active_area(area: LevelArea) -> void:
	if area == active_area:
		return
	
	if active_area:
		editor.viewport_handler.store_view(active_area)
		editor.world.remove_child(active_area)
	
	active_area = area
	editor.world.add_child(area)
	editor.viewport_handler.restore_view(area)
	area_changed.emit(area)
	var layer: LevelLayer = area.get_layer(area.active_layer)
	set_active_layer(layer if layer else area.get_layers().front())


func set_active_layer(layer: LevelLayer) -> void:
	var switched: bool = active_layer != null and active_layer != layer
	active_layer = layer
	active_area.active_layer = layer.index
	refresh_layer_visuals(switched, switched)
	layer_changed.emit(layer)


func step_layer(direction: int) -> void:
	var layers: Array[LevelLayer] = active_area.get_layers()
	var at: int = clampi(layers.find(active_layer) + direction, 0, layers.size() - 1)
	set_active_layer(layers.get(at))


func refresh_layer_visuals(animate: bool = false, pulse: bool = false) -> void:
	if active_area == null:
		return
	
	if _visual_tween and _visual_tween.is_valid():
		_visual_tween.kill()
	
	var duration: float = fade_duration if animate and Settings.ui.animations.current_value else 0.0
	if duration > 0.0:
		_visual_tween = create_tween().set_parallel().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	
	var focus: float = active_layer.distance if focus_enabled and active_layer else 0.0
	if duration > 0.0:
		_visual_tween.tween_method(_set_focus_distance, _focus_distance, focus, depth_duration)
	else:
		_set_focus_distance(focus)
	
	for layer: LevelLayer in active_area.get_layers():
		layer.modulation_enabled = modulation_enabled
		var target: Color = ghost_tint if focus_enabled and layer != active_layer else Color.WHITE
		if duration <= 0.0:
			layer.tint = target
			continue
		
		if pulse and layer == active_layer and not focus_enabled:
			layer.tint = pulse_tint
		_visual_tween.tween_property(layer, ^"tint", target, duration)


func _set_focus_distance(focus: float) -> void:
	_focus_distance = focus
	if active_area == null:
		return
	
	for layer: LevelLayer in active_area.get_layers():
		layer.focus_distance = focus


func add_layer(behind: LevelLayer) -> void:
	var layer: LevelLayer = LevelLayer.new()
	layer.apply_data(LayerData.create(behind.index))
	var shifted: Array[LevelLayer] = active_area.get_layers().filter(func(each: LevelLayer) -> bool: return each.index >= behind.index)
	editor.history_handler.create("Add Layer") \
		.do(_shift_layers.bind(active_area, shifted, 1)) \
		.do(_attach_layer.bind(active_area, layer)) \
		.undo(_detach_layer.bind(active_area, layer)) \
		.undo(_shift_layers.bind(active_area, shifted, -1)) \
		.keep_on_do(layer) \
		.commit()


func get_selectable_objects() -> Array[GameObject]:
	return active_layer.get_objects() if focus_enabled else active_area.get_all_objects()


func get_anchor_layer(area: LevelArea = active_area) -> LevelLayer:
	for object: GameObject in area.get_all_objects():
		if object.unique and object.id == &"player_mario":
			return area.get_layer_of(object)
	
	return area.get_layer(0)


func get_layer_label(layer: LevelLayer) -> String:
	if not layer.layer_name.is_empty():
		return layer.layer_name
	
	var anchor: LevelLayer = get_anchor_layer()
	return "Layer %d" % (layer.index - (anchor.index if anchor else 0))


func remove_layer(layer: LevelLayer) -> void:
	if active_area.get_layers().size() <= 1:
		return
	
	editor.history_handler.create("Remove Layer") \
		.do(_detach_layer.bind(active_area, layer)) \
		.undo(_attach_layer.bind(active_area, layer)) \
		.keep_on_undo(layer) \
		.commit()


func move_layer(layer: LevelLayer, direction: int) -> void:
	var layers: Array[LevelLayer] = active_area.get_layers()
	var at: int = layers.find(layer) + direction
	if at < 0 or at >= layers.size():
		return
	
	var other: LevelLayer = layers.get(at)
	editor.history_handler.create("Move Layer") \
		.do(_swap_layers.bind(active_area, layer, other)) \
		.undo(_swap_layers.bind(active_area, layer, other)) \
		.commit()


func set_layer_property(layer: LevelLayer, property: StringName, value: Variant) -> void:
	if not LAYER_PROPERTIES.has(property) or layer.get(property) == value:
		return
	
	editor.history_handler.create("Edit Layer %s" % String(property).capitalize(), UndoRedo.MERGE_ENDS) \
		.do(_set_layer_property.bind(layer, property, value)) \
		.undo(_set_layer_property.bind(layer, property, layer.get(property))) \
		.commit()


func add_area() -> void:
	var area: LevelArea = LevelArea.build(AreaData.create("Area %d" % (areas.size() + 1)), GameObject.Context.EDITOR)
	editor.history_handler.create("Add Area") \
		.do(_insert_area.bind(area, areas.size())) \
		.undo(_remove_area.bind(area)) \
		.keep_on_do(area) \
		.commit()


func remove_area(area: LevelArea) -> void:
	if areas.size() <= 1:
		return
	
	editor.history_handler.create("Remove Area") \
		.do(_remove_area.bind(area)) \
		.undo(_insert_area.bind(area, areas.find(area))) \
		.keep_on_undo(area) \
		.commit()


func move_area(area: LevelArea, direction: int) -> void:
	var at: int = areas.find(area)
	var target: int = at + direction
	if target < 0 or target >= areas.size():
		return
	
	editor.history_handler.create("Move Area") \
		.do(_place_area.bind(area, target)) \
		.undo(_place_area.bind(area, at)) \
		.commit()


func rename_area(area: LevelArea, area_name: String) -> void:
	if area.area_name == area_name or area_name.is_empty():
		return
	
	editor.history_handler.create("Rename Area", UndoRedo.MERGE_ENDS) \
		.do(_set_area_name.bind(area, area_name)) \
		.undo(_set_area_name.bind(area, area.area_name)) \
		.commit()


func _attach_layer(area: LevelArea, layer: LevelLayer) -> void:
	area.insert_layer(layer)
	if area == active_area:
		set_active_layer(layer)
	structure_changed.emit()


func _detach_layer(area: LevelArea, layer: LevelLayer) -> void:
	var layers: Array[LevelLayer] = area.get_layers()
	var neighbour: LevelLayer = layers.get(maxi(layers.find(layer) - 1, 0))
	area.remove_layer(layer)
	if area == active_area and active_layer == layer:
		set_active_layer(neighbour if neighbour != layer else area.get_layers().front())
	refresh_layer_visuals()
	structure_changed.emit()


func _shift_layers(area: LevelArea, layers: Array[LevelLayer], amount: int) -> void:
	for layer: LevelLayer in layers:
		layer.index += amount
	area.sort_layers()


func _place_area(area: LevelArea, at: int) -> void:
	areas.erase(area)
	areas.insert(at, area)
	structure_changed.emit()


func _swap_layers(area: LevelArea, first: LevelLayer, second: LevelLayer) -> void:
	var index: int = first.index
	first.index = second.index
	second.index = index
	area.sort_layers()
	structure_changed.emit()


func _set_layer_property(layer: LevelLayer, property: StringName, value: Variant) -> void:
	layer.set(property, value)
	structure_changed.emit()


func _insert_area(area: LevelArea, at: int) -> void:
	areas.insert(at, area)
	set_active_area(area)
	structure_changed.emit()


func _remove_area(area: LevelArea) -> void:
	var at: int = areas.find(area)
	areas.erase(area)
	if area == active_area:
		set_active_area(areas.get(clampi(at - 1, 0, areas.size() - 1)))
	structure_changed.emit()


func _set_area_name(area: LevelArea, area_name: String) -> void:
	area.area_name = area_name
	structure_changed.emit()


func _free_detached_areas() -> void:
	for area: LevelArea in areas:
		if is_instance_valid(area) and not area.is_inside_tree():
			area.free()
