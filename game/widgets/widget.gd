@abstract class_name PropertyWidget
extends Control

const SCENES: Dictionary[StringName, String] = {
	&"enum": "uid://baakk5qyhrm3q",
	&"bool": "uid://buhxjd0lc4clj",
	&"range": "uid://bpte0j20nd05a",
	&"enum_slider": "uid://b7ub6g70ijha2",
	&"Array[InputEvent]": "uid://bnlgql4fauuga",
	&"int": "res://game/widgets/widget_number/widget_number.tscn",
	&"float": "res://game/widgets/widget_number/widget_number.tscn",
	&"String": "res://game/widgets/widget_string/widget_string.tscn",
	&"text": "res://game/widgets/widget_text/widget_text.tscn",
	&"Vector2": "res://game/widgets/widget_vector2/widget_vector2.tscn",
	&"Vector2i": "res://game/widgets/widget_vector2/widget_vector2.tscn",
	&"vector2_range": "res://game/widgets/widget_vector2_range/widget_vector2_range.tscn",
	&"Texture2D": "res://game/widgets/widget_texture/widget_texture.tscn",
	&"flags": "res://game/widgets/widget_flags/widget_flags.tscn",
	&"Color": "res://game/widgets/widget_color/widget_color.tscn",
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


static func supports(kind: StringName) -> bool:
	return _registered.has(kind) or SCENES.has(kind)


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


func set_editable(editable: bool) -> void:
	modulate.a = 1.0 if editable else 0.4
	_set_editable(self, editable)


static func _set_editable(node: Node, editable: bool) -> void:
	for child: Node in node.get_children():
		if child is BaseButton:
			(child as BaseButton).disabled = not editable
			GDSS.refresh(child)
		elif child is LineEdit:
			(child as LineEdit).editable = editable
			GDSS.refresh(child)
		elif child is TextEdit:
			(child as TextEdit).editable = editable
			GDSS.refresh(child)
		elif child is Slider:
			(child as Slider).editable = editable
		elif child is Panel and child.get_parent() is Slider:
			if editable:
				GDSS.clear_state(child)
			else:
				GDSS.set_state(child, "disabled")
		_set_editable(child, editable)


func _info(_widget_info: Dictionary) -> void:
	pass


func _commit(widget_value: Variant) -> void:
	if binding != null:
		binding.set_value(widget_value)
