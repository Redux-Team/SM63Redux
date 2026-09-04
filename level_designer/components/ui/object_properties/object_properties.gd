class_name LDObjectPropertyList
extends MarginContainer


@export var _container: VBoxContainer
@export var _bool_widget_scene: PackedScene
@export var _vector2_widget_scene: PackedScene
@export var _float_widget_scene: PackedScene
@export var _int_widget_scene: PackedScene
@export var _option_widget_scene: PackedScene
@export var _string_widget_scene: PackedScene


func load_selection(objects: Array[LDObject]) -> void:
	_clear()
	var handler: LDObjectHandler = LD.get_object_handler()
	var properties: Array[LDProperty] = _by_section(handler.get_shared_properties(objects))
	var read_only: bool = _selection_is_read_only(objects)
	var section: StringName = &""
	for prop: LDProperty in properties:
		if not prop.visible_in_editor:
			continue
		var widget: LDPropertyWidget = _create_widget(prop)
		if not widget:
			continue
		# Only once a section is known to have something to show, so an object whose whole section
		# is hidden doesn't get a heading over nothing.
		if prop.group != section:
			section = prop.group
			if not section.is_empty():
				_container.add_child(_make_section_header(String(section)))
		var current_value: Variant = handler.get_property_value(objects, prop.key)
		if widget is LDOptionWidget and not objects.is_empty():
			# A property can list fixed choices itself; the object only gets asked when it doesn't,
			# which is how style presets read from a directory stay dynamic.
			var choices: PackedStringArray = prop.options if not prop.options.is_empty() else objects[0].get_property_options(prop.key)
			(widget as LDOptionWidget).set_options(choices)
		widget.setup(prop, current_value)
		if read_only:
			_make_read_only(widget)
		else:
			widget.value_changed.connect(func(key: StringName, value: Variant) -> void:
				handler.set_property_on_selection(key, value)
				var applied: Variant = handler.get_property_value(handler.get_placed_selection(), key)
				widget._on_property_applied(applied)
			)
		_container.add_child(widget)


## Orders the panel by section while keeping each section's own order: ungrouped fields lead, then
## every named section in the order it first turns up, so the layout follows how the object was
## defined rather than the alphabet.
func _by_section(properties: Array[LDProperty]) -> Array[LDProperty]:
	var order: Array[StringName] = [&""]
	for prop: LDProperty in properties:
		if prop.group not in order:
			order.append(prop.group)
	
	var result: Array[LDProperty] = []
	for group: StringName in order:
		for prop: LDProperty in properties:
			if prop.group == group:
				result.append(prop)
	
	return result


func _make_section_header(text: String) -> Control:
	var header: Label = Label.new()
	header.text = text
	header.modulate = Color(1.0, 1.0, 1.0, 0.6)
	header.add_theme_constant_override(&"line_spacing", 0)
	
	var spacer: MarginContainer = MarginContainer.new()
	spacer.add_theme_constant_override(&"margin_top", 6)
	spacer.add_child(header)
	
	return spacer


## Linked-stamp "ghost" copies are read-only; their properties can't be edited.
func _selection_is_read_only(objects: Array[LDObject]) -> bool:
	for obj: LDObject in objects:
		if LD.get_stamp_handler().is_linked_readonly(obj):
			return true
	return false


func _make_read_only(widget: Control) -> void:
	widget.modulate = Color(1.0, 1.0, 1.0, 0.5)
	for node: Node in widget.find_children("*", "", true, false):
		if node is SpinBox:
			(node as SpinBox).editable = false
		elif node is LineEdit:
			(node as LineEdit).editable = false
		elif node is BaseButton:
			(node as BaseButton).disabled = true
			GDSS.refresh(node)


func _on_show() -> void:
	load_selection(LD.get_object_handler().get_placed_selection())


func _clear() -> void:
	for child: Node in _container.get_children():
		child.queue_free()


func _create_widget(prop: LDProperty) -> LDPropertyWidget:
	match prop.type:
		LDProperty.Type.BOOL:
			return _bool_widget_scene.instantiate() as LDPropertyWidget
		LDProperty.Type.FLOAT:
			return _float_widget_scene.instantiate() as LDPropertyWidget
		LDProperty.Type.INT:
			return _int_widget_scene.instantiate() as LDPropertyWidget
		LDProperty.Type.VECTOR2:
			return _vector2_widget_scene.instantiate() as LDPropertyWidget
		LDProperty.Type.OPTION:
			return _option_widget_scene.instantiate() as LDPropertyWidget
		LDProperty.Type.STRING:
			if _string_widget_scene:
				return _string_widget_scene.instantiate() as LDPropertyWidget
	return null
