class_name LDInspector
extends LDPanel

const TRANSFORM_SECTION: StringName = &"Transform"

@export var container: VBoxContainer
@export var empty_label: Label
@export var section_scene: PackedScene
@export var reset_icon: Texture2D

var _bindings: Array[PropertyBinding] = []
var _objects: Array[GameObject] = []
var _signature: Array = []


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
	var objects: Array[GameObject] = editor.object_handler.selection.get_objects()
	var signature: Array = _signature_of(objects)
	_objects = objects
	if signature == _signature and not _bindings.is_empty():
		_refresh()
		return
	
	_signature = signature
	for child: Node in container.get_children():
		child.queue_free()
	_bindings.clear()
	empty_label.visible = objects.is_empty()
	if objects.is_empty():
		return
	
	_add_transform(objects)
	refit()
	var section: StringName = TRANSFORM_SECTION
	for property: ObjectProperty in _get_shared_properties(objects):
		if property.group != section:
			section = property.group
			_add_section(String(section) if not section.is_empty() else "Properties")
		
		var key: StringName = property.key
		_add(PropertyBinding.new(
			func() -> Variant: return _objects.front().get_value(key),
			func(value: Variant) -> void: editor.object_handler.set_values(_objects, key, value),
			property.get_label(), property.to_info()), property.coerce(null))


func _refresh() -> void:
	for binding: PropertyBinding in _bindings:
		binding.refresh()


func _add(binding: PropertyBinding, default: Variant = null) -> void:
	var row: Control = make_row(binding, default, reset_icon)
	if row:
		_bindings.append(binding)
		container.add_child(row)


static func make_row(binding: PropertyBinding, default: Variant, icon: Texture2D) -> Control:
	var widget: PropertyWidget = PropertyWidget.create(binding)
	if widget == null or default == null:
		return widget
	
	var row: HBoxContainer = HBoxContainer.new()
	widget.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(widget)
	var reset: TextureButton = TextureButton.new()
	reset.texture_normal = icon
	reset.ignore_texture_size = true
	reset.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	reset.custom_minimum_size = Vector2(18.0, 18.0)
	reset.focus_mode = Control.FOCUS_NONE
	reset.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	reset.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	reset.pressed.connect(binding.set_value.bind(default))
	Tooltip.set_text(reset, "Reset to Default", Tooltip.Placement.ABOVE)
	row.add_child(reset)
	var sync: Callable = func(value: Variant) -> void:
		reset.modulate.a = 0.0 if value == default else 1.0
		reset.mouse_filter = Control.MOUSE_FILTER_IGNORE if value == default else Control.MOUSE_FILTER_STOP
	binding.changed.connect(sync)
	sync.call(binding.get_value())
	return row


func _add_section(text: String) -> void:
	var header: Label = section_scene.instantiate()
	header.text = text
	container.add_child(header)


func _signature_of(objects: Array[GameObject]) -> Array:
	if objects.is_empty():
		return []
	
	var signature: Array = [objects.size() == 1 and objects.front().has_flag(GameObject.Flag.MOVABLE), _all_have(objects, GameObject.Flag.ROTATABLE), _all_have(objects, GameObject.Flag.SCALABLE)]
	for property: ObjectProperty in _get_shared_properties(objects):
		signature.append_array([property.key, property.to_info(), property.coerce(null)])
	
	return signature


static func _all_have(objects: Array[GameObject], flag: GameObject.Flag) -> bool:
	return objects.all(func(object: GameObject) -> bool: return object.has_flag(flag))


func _add_transform(objects: Array[GameObject]) -> void:
	_add_section(String(TRANSFORM_SECTION))
	if objects.size() == 1 and objects.front().has_flag(GameObject.Flag.MOVABLE):
		_add(PropertyBinding.new(
			func() -> Variant: return _objects.front().position,
			func(value: Variant) -> void: _edit_transforms(_objects, func(object: GameObject) -> void: object.position = value),
			"Position", {"type": TYPE_VECTOR2, "widget": &"vector2_range", "step": 1.0}))
	
	if _all_have(objects, GameObject.Flag.ROTATABLE):
		_add(PropertyBinding.new(
			func() -> Variant: return _objects.front().rotation_degrees,
			func(value: Variant) -> void: _edit_transforms(_objects, func(object: GameObject) -> void: object.rotation_degrees = value),
			"Rotation", {"type": TYPE_FLOAT}))
	
	if _all_have(objects, GameObject.Flag.SCALABLE):
		_add(PropertyBinding.new(
			func() -> Variant: return _objects.front().scale,
			func(value: Variant) -> void: _edit_transforms(_objects, func(object: GameObject) -> void: object.scale = value),
			"Scale", {"type": TYPE_VECTOR2, "widget": &"vector2_range", "hint_string": "0.25,4,0.05", "format": "%.2fx"}))


func _edit_transforms(objects: Array[GameObject], edit: Callable) -> void:
	var before: Array[Transform2D] = LDObjectHandler.get_transforms(objects)
	for object: GameObject in objects:
		edit.call(object)
	
	editor.object_handler.transform_objects(objects, before, LDObjectHandler.get_transforms(objects), "Edit Transform", true)


static func is_editable(property: ObjectProperty) -> bool:
	return not property.hidden and property.type != ObjectProperty.Type.PACKED_VECTOR2


func _get_shared_properties(objects: Array[GameObject]) -> Array[ObjectProperty]:
	var shared: Array[ObjectProperty] = []
	var order: Array[StringName] = [&""]
	for property: ObjectProperty in (objects.front() as GameObject).properties:
		if not is_editable(property):
			continue
		
		if objects.all(func(object: GameObject) -> bool: return object.get_object_property(property.key) != null):
			shared.append(property)
			if not order.has(property.group):
				order.append(property.group)
	
	var sorted: Array[ObjectProperty] = []
	for group: StringName in order:
		sorted.append_array(shared.filter(func(property: ObjectProperty) -> bool: return property.group == group))
	return sorted
