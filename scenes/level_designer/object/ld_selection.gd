class_name LDSelection
extends LDComponent

signal changed

@export var deselect_button: BaseButton
@export var delete_button: BaseButton

var _objects: Array[GameObject] = []
var _forgotten: bool = false


func _setup() -> void:
	LD.bind_button(deselect_button, clear)
	LD.bind_button(delete_button, func() -> void: editor.object_handler.remove_objects(get_objects()))
	changed.connect(_refresh_buttons)
	_refresh_buttons()
	editor.level_handler.level_opened.connect(clear)
	editor.level_handler.area_changed.connect(clear.unbind(1))
	editor.level_handler.structure_changed.connect(_prune)
	editor.object_handler.objects_changed.connect(_prune)


func _unhandled_input(event: InputEvent) -> void:
	if editor.is_shortcut(event, &"ld_select_all"):
		set_objects(editor.level_handler.get_selectable_objects())
	elif editor.is_shortcut(event, &"ld_back") and not editor.interface_handler.is_panel_open():
		clear()
	elif editor.is_shortcut(event, &"ld_delete"):
		editor.object_handler.remove_objects(get_objects())
	else:
		return
	
	get_viewport().set_input_as_handled()


func get_objects() -> Array[GameObject]:
	return _objects.duplicate()


func set_objects(objects: Array[GameObject]) -> void:
	_objects = objects.filter(_is_selectable)
	changed.emit()


func add(objects: Array[GameObject]) -> void:
	for object: GameObject in objects:
		if not _objects.has(object) and _is_selectable(object):
			_objects.append(object)
	
	changed.emit()


func toggle(object: GameObject) -> void:
	if _objects.has(object):
		_objects.erase(object)
	elif _is_selectable(object):
		_objects.append(object)
	
	changed.emit()


func clear() -> void:
	if _objects.is_empty():
		return
	
	_objects.clear()
	changed.emit()


func has(object: GameObject) -> bool:
	return _objects.has(object)


func is_empty() -> bool:
	return _objects.is_empty()


func get_global_bounds() -> Rect2:
	var bounds: Rect2 = Rect2()
	for i: int in _objects.size():
		var rect: Rect2 = _objects.get(i).get_global_bounds()
		bounds = rect if i == 0 else bounds.merge(rect)
	
	return bounds


func forget(object: GameObject) -> void:
	if _objects.has(object):
		_objects.erase(object)
		_forgotten = true


func _prune() -> void:
	var kept: Array[GameObject] = _objects.filter(func(object: GameObject) -> bool: return is_instance_valid(object) and object.is_inside_tree())
	if kept.size() != _objects.size() or _forgotten:
		_forgotten = false
		_objects = kept
		changed.emit()


func _is_selectable(object: GameObject) -> bool:
	return is_instance_valid(object) and object.is_inside_tree() and object.has_flag(GameObject.Flag.SELECTABLE)


func _refresh_buttons() -> void:
	LD.set_disabled(deselect_button, _objects.is_empty())
	LD.set_disabled(delete_button, not _objects.any(func(object: GameObject) -> bool: return object.has_flag(GameObject.Flag.DELETABLE)))
