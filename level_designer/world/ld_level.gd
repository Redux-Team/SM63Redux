class_name LDLevel
extends Node2D


## A level is a stack of areas, only one of which is active (visible/editable) at a time. Each area
## owns its own layers and background; switching the active area swaps what the editor shows.


signal active_area_changed(area: LDArea)
## Emitted when the set of areas changes (added/removed/reordered/renamed), so UI such as the area
## spinbox can refresh.
signal areas_changed


static var _inst: LDLevel


var _areas: Array[LDArea] = []
var _active_index: int = 0
## Always mirrors _areas[_active_index] so the many LDLevel.get_active_area() callers keep working.
var _active_area: LDArea


func _init() -> void:
	_inst = self


## Returns the currently active area.
static func get_active_area() -> LDArea:
	return _inst._active_area


## All areas in creation order.
func get_areas() -> Array[LDArea]:
	return _areas


func get_active_index() -> int:
	return _active_index


## Creates a new area (with the default background), hidden unless it is the first one.
func add_area(area_name: String) -> LDArea:
	var area: LDArea = LDArea.new()
	area.name = "Area"
	area.area_name = area_name
	add_child(area)
	area.apply_default_background()
	area.visible = _areas.is_empty()
	_areas.append(area)
	if _areas.size() == 1:
		_active_area = area
		_active_index = 0
	areas_changed.emit()
	return area


## Removes an area, picking a neighbour as the new active one. The last area can't be removed.
func remove_area(area: LDArea) -> void:
	if _areas.size() <= 1 or not _areas.has(area):
		return
	var was_active: bool = area == _active_area
	var index: int = _areas.find(area)
	_areas.erase(area)
	area.queue_free()
	if was_active:
		set_active_area_index(clampi(index, 0, _areas.size() - 1))
	elif index < _active_index:
		_active_index -= 1
	areas_changed.emit()


## Renames an area, cascading the change to everything that references it by name (scenarios, stamp
## instances) so those references don't break.
## True if another area (not `exclude`) already uses this name.
func is_area_name_taken(area_name: String, exclude: LDArea = null) -> bool:
	for area: LDArea in _areas:
		if area != exclude and area.area_name == area_name:
			return true
	return false


## The lowest free "Area N" name, for new areas.
func suggest_area_name() -> String:
	var n: int = 1
	while is_area_name_taken("Area %d" % n):
		n += 1
	return "Area %d" % n


func rename_area(area: LDArea, area_name: String) -> void:
	var old_name: String = area.area_name
	# Names must be unique and non-empty: empty is reserved (a scenario with no area link means
	# "the first area"), and a duplicate would make name-based references ambiguous.
	if area_name.is_empty() or old_name == area_name or is_area_name_taken(area_name, area):
		return
	area.area_name = area_name
	LD.get_scenario_handler().rename_area_references(old_name, area_name)
	LD.get_stamp_handler().rename_area_references(old_name, area_name)
	areas_changed.emit()


## Swaps an area with its neighbour `delta` away in the list order.
func move_area(area: LDArea, delta: int) -> void:
	var pos: int = _areas.find(area)
	var target: int = pos + delta
	if pos < 0 or target < 0 or target >= _areas.size():
		return
	_areas[pos] = _areas[target]
	_areas[target] = area
	_active_index = _areas.find(_active_area)
	areas_changed.emit()


## Makes the area at `index` the active (visible/editable) one, hiding the others and swapping the
## editor view to that area's saved camera. `store_previous` saves the current view into the area
## being left first; pass false when loading (the live view is irrelevant then).
func set_active_area_index(index: int, store_previous: bool = true) -> void:
	if index < 0 or index >= _areas.size():
		return
	if store_previous and is_instance_valid(_active_area):
		_active_area.store_view()
	_active_index = index
	_active_area = _areas[index]
	for i: int in _areas.size():
		_areas[i].visible = i == index
	_active_area.restore_view()
	active_area_changed.emit(_active_area)
	# Kick the viewport so the background parallax + grid shader reposition to the restored view
	# immediately (otherwise they only update on the next camera move).
	var viewport: LDViewport = LD.get_editor_viewport()
	if is_instance_valid(viewport):
		viewport.refresh()


## Index of the area with the given name, or the first area when the name is empty, or -1 if none.
func area_index_for_name(area_name: String) -> int:
	if area_name.is_empty():
		return 0 if not _areas.is_empty() else -1
	for i: int in _areas.size():
		if _areas[i].area_name == area_name:
			return i
	return -1


## Sets the active area directly (kept for callers that hold an LDArea reference).
func set_active_area(area: LDArea) -> void:
	var index: int = _areas.find(area)
	if index >= 0:
		set_active_area_index(index)
	else:
		_active_area = area


## Removes every area (used when loading a level before rebuilding from saved data).
func clear_areas() -> void:
	for area: LDArea in _areas:
		area.queue_free()
	_areas.clear()
	_active_area = null
	_active_index = 0


## Returns the active layer of the currently active area.
static func get_active_layer() -> LDLayer:
	return get_active_area().get_active_layer()


## Returns the objects root node of the active layer in the active area.
static func get_active_objects_root() -> Node2D:
	return get_active_area().get_active_layer().get_objects_root()
