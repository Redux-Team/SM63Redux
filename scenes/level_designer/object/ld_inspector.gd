class_name LDInspector
extends LDPanel

const TRANSFORM_SECTION: StringName = &"Transform"

@export var container: VBoxContainer
@export var empty_label: Label
@export var section_scene: PackedScene

var _bindings: Array[PropertyBinding] = []


func _setup() -> void:
	super()
	editor.object_handler.selection.changed.connect(_on_selection_changed)
	editor.object_handler.objects_changed.connect(_refresh)
	_on_selection_changed()


func get_title() -> String:
	var objects: Array[GameObject] = editor.object_handler.selection.get_objects()
	if objects.size() == 1:
		return "Properties - %s" % objects.front().display_name
	return "Properties - %d objects" % objects.size()


func _on_open() -> void:
	_rebuild()


func _on_selection_changed() -> void:
	var empty: bool = editor.object_handler.selection.is_empty()
	LD.set_disabled(toggle_button, empty)
	if empty:
		close()
	elif is_open():
		_rebuild()
		editor.interface_handler.window.set_title(get_title())


func _rebuild() -> void:
	for child: Node in container.get_children():
		child.queue_free()
	_bindings.clear()
	
	var objects: Array[GameObject] = editor.object_handler.selection.get_objects()
	empty_label.visible = objects.is_empty()
	if objects.is_empty():
		return
	
	_add_transform(objects)
	var section: StringName = TRANSFORM_SECTION
	for property: ObjectProperty in _get_shared_properties(objects):
		if property.group != section:
			section = property.group
			_add_section(String(section) if not section.is_empty() else "Properties")
		
		var key: StringName = property.key
		_add(PropertyBinding.new(
			func() -> Variant: return objects.front().get_value(key),
			func(value: Variant) -> void: editor.object_handler.set_values(objects, key, value),
			property.get_label(), property.to_info()))


func _refresh() -> void:
	for binding: PropertyBinding in _bindings:
		binding.refresh()


func _add(binding: PropertyBinding) -> void:
	var widget: PropertyWidget = PropertyWidget.create(binding)
	if widget:
		container.add_child(widget)
		_bindings.append(binding)


func _add_section(text: String) -> void:
	var header: Label = section_scene.instantiate()
	header.text = text
	container.add_child(header)


func _add_transform(objects: Array[GameObject]) -> void:
	var first: GameObject = objects.front()
	_add_section(String(TRANSFORM_SECTION))
	if objects.size() == 1 and first.has_flag(GameObject.Flag.MOVABLE):
		_add(PropertyBinding.new(
			func() -> Variant: return first.position,
			func(value: Variant) -> void: _edit_transforms(objects, func(object: GameObject) -> void: object.position = value),
			"Position", {"type": TYPE_VECTOR2}))
	
	if objects.all(func(object: GameObject) -> bool: return object.has_flag(GameObject.Flag.ROTATABLE)):
		_add(PropertyBinding.new(
			func() -> Variant: return first.rotation_degrees,
			func(value: Variant) -> void: _edit_transforms(objects, func(object: GameObject) -> void: object.rotation_degrees = value),
			"Rotation", {"type": TYPE_FLOAT}))
	
	if objects.all(func(object: GameObject) -> bool: return object.has_flag(GameObject.Flag.SCALABLE)):
		_add(PropertyBinding.new(
			func() -> Variant: return first.scale,
			func(value: Variant) -> void: _edit_transforms(objects, func(object: GameObject) -> void: object.scale = value),
			"Scale", {"type": TYPE_VECTOR2}))


func _edit_transforms(objects: Array[GameObject], edit: Callable) -> void:
	var before: Array[Transform2D] = LDObjectHandler.get_transforms(objects)
	for object: GameObject in objects:
		edit.call(object)
	
	editor.object_handler.transform_objects(objects, before, LDObjectHandler.get_transforms(objects), "Edit Transform", true)


func _get_shared_properties(objects: Array[GameObject]) -> Array[ObjectProperty]:
	var shared: Array[ObjectProperty] = []
	var order: Array[StringName] = [&""]
	for property: ObjectProperty in (objects.front() as GameObject).properties:
		if property.hidden or property.type == ObjectProperty.Type.PACKED_VECTOR2:
			continue
		
		if objects.all(func(object: GameObject) -> bool: return object.get_object_property(property.key) != null):
			shared.append(property)
			if not order.has(property.group):
				order.append(property.group)
	
	var sorted: Array[ObjectProperty] = []
	for group: StringName in order:
		sorted.append_array(shared.filter(func(property: ObjectProperty) -> bool: return property.group == group))
	return sorted

