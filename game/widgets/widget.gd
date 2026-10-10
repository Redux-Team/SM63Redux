@abstract class_name PropertyWidget
extends Control

const SCENES: Dictionary[StringName, String] = {
	&"enum": "uid://baakk5qyhrm3q",
}

static var _registered: Dictionary[StringName, PackedScene] = {}

var binding: PropertyBinding:
	set(value):
		if binding != null and binding.changed.is_connected(_value):
			binding.changed.disconnect(_value)
		binding = value
		if binding == null:
			return
		binding.changed.connect(_value)
		_name(binding.label)
		_info(binding.info)
		_value(binding.get_value())


static func register(kind: StringName, scene: PackedScene) -> void:
	_registered.set(kind, scene)


static func create(property_binding: PropertyBinding) -> PropertyWidget:
	var kind: StringName = property_binding.kind()
	var scene: PackedScene = _registered.get(kind)
	if scene == null and SCENES.has(kind):
		scene = load(SCENES.get(kind))
		_registered.set(kind, scene)
	if scene == null:
		push_error("PropertyWidget: no widget registered for kind '%s'." % kind)
		return null
	var widget: PropertyWidget = scene.instantiate() as PropertyWidget
	widget.binding = property_binding
	return widget


@abstract func _name(widget_name: String) -> void
@abstract func _value(widget_value: Variant) -> void


func _info(_widget_info: Dictionary) -> void:
	pass


func _commit(widget_value: Variant) -> void:
	if binding != null:
		binding.set_value(widget_value)
