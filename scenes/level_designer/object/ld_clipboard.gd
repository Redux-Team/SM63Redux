class_name LDClipboard
extends LDComponent

const DUPLICATE_OFFSET: Vector2 = Vector2(16.0, 16.0)

@export var cut_button: BaseButton
@export var copy_button: BaseButton
@export var paste_button: BaseButton
@export var duplicate_button: BaseButton

var _entries: Array[ObjectData] = []
var _anchor: Vector2 = Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	var selected: Array[GameObject] = editor.object_handler.selection.get_objects()
	if editor.is_shortcut(event, &"ld_copy"):
		copy(selected)
	elif editor.is_shortcut(event, &"ld_cut"):
		cut(selected)
	elif editor.is_shortcut(event, &"ld_paste"):
		paste(_get_paste_position())
	elif editor.is_shortcut(event, &"ld_duplicate"):
		duplicate_objects(selected)
	else:
		return
	
	get_viewport().set_input_as_handled()


func _setup() -> void:
	editor.object_handler.selection.changed.connect(_refresh_buttons)
	LD.bind_button(cut_button, func() -> void: cut(editor.object_handler.selection.get_objects()))
	LD.bind_button(copy_button, func() -> void: copy(editor.object_handler.selection.get_objects()))
	LD.bind_button(paste_button, func() -> void: paste(_get_paste_position()))
	LD.bind_button(
			duplicate_button,
			func() -> void:
				duplicate_objects(editor.object_handler.selection.get_objects())
	)
	_refresh_buttons()


func copy(objects: Array[GameObject]) -> void:
	var copyable: Array[GameObject] = objects.filter(
			func(object: GameObject) -> bool:
				return object.has_flag(GameObject.Flag.COPYABLE)
	)
	if copyable.is_empty():
		return
	
	_entries.clear()
	_anchor = Vector2.ZERO
	for object: GameObject in copyable:
		_entries.append(object.to_data())
		_anchor += object.position / copyable.size()
	
	_refresh_buttons()


func cut(objects: Array[GameObject]) -> void:
	copy(objects)
	editor.object_handler.remove_objects(objects, "Cut Objects")


func paste(local_position: Vector2) -> void:
	editor.object_handler.add_objects(
			_instantiate(_entries, local_position - _anchor),
			editor.level_handler.active_layer,
			"Paste Objects",
	)


func duplicate_objects(objects: Array[GameObject]) -> void:
	var entries: Array[ObjectData] = []
	for object: GameObject in objects:
		if object.has_flag(GameObject.Flag.COPYABLE):
			entries.append(object.to_data())
	
	editor.object_handler.add_objects(
			_instantiate(entries, DUPLICATE_OFFSET),
			editor.level_handler.active_layer,
			"Duplicate Objects",
	)


func _instantiate(entries: Array[ObjectData], offset: Vector2) -> Array[GameObject]:
	var objects: Array[GameObject] = []
	for entry: ObjectData in entries:
		var data: ObjectData = entry.duplicate_with_new_uuid()
		data.position += offset
		var object: GameObject = ObjectRegistry.spawn(data, GameObject.Context.EDITOR)
		if object:
			objects.append(object)
	
	return objects


func _get_paste_position() -> Vector2:
	return editor.viewport_handler.get_layer_mouse(editor.level_handler.active_layer)


func _refresh_buttons() -> void:
	var empty: bool = editor.object_handler.selection.is_empty()
	LD.set_disabled(cut_button, empty)
	LD.set_disabled(copy_button, empty)
	LD.set_disabled(duplicate_button, empty)
	LD.set_disabled(paste_button, _entries.is_empty())
