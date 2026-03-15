class_name LDObjectPropertyList
extends MarginContainer


@export var _container: VBoxContainer
@export var _bool_widget_scene: PackedScene
@export var _vector2_widget_scene: PackedScene


func load_selection(objects: Array[LDObject]) -> void:
	_clear()
	var handler: LDObjectHandler = LD.get_object_handler()
	var properties: Array[LDProperty] = handler.get_shared_properties(objects)
	for prop: LDProperty in properties:
		if not prop.visible_in_editor:
			continue
		var widget: LDPropertyWidget = _create_widget(prop)
		if not widget:
			continue
		var current_value: Variant = handler.get_property_value(objects, prop.key)
		widget.setup(prop, current_value)
		widget.value_changed.connect(func(key: StringName, value: Variant) -> void:
			handler.set_property_on_selection(key, value)
			var clamped: Variant = handler.get_property_value(handler.get_placed_selection(), key)
			widget._on_property_applied(clamped)
		)
		_container.add_child(widget)


func _on_show() -> void:
	load_selection(LD.get_object_handler().get_placed_selection())


func _clear() -> void:
	for child: Node in _container.get_children():
		child.queue_free()


func _create_widget(prop: LDProperty) -> LDPropertyWidget:
	match prop.type:
		LDProperty.Type.BOOL:
			return _bool_widget_scene.instantiate() as LDPropertyWidget
		#LDProperty.Type.FLOAT, LDProperty.Type.INT:
			#return _float_widget_scene.instantiate() as LDPropertyWidget
		LDProperty.Type.VECTOR2:
			return _vector2_widget_scene.instantiate() as LDPropertyWidget
	return null
