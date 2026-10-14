class_name LDPlacementPanel
extends LDPanel

@export var container: VBoxContainer
@export var empty_label: Label
@export var section_scene: PackedScene
@export var reset_icon: Texture2D

var _entry: ObjectRegistry.Entry
var _values: Dictionary = {}
var _on_change: Callable
var _bindings: Array[PropertyBinding] = []


func edit(entry: ObjectRegistry.Entry, values: Dictionary, on_change: Callable) -> void:
	_entry = entry
	_values = values
	_on_change = on_change
	_build()
	if is_open():
		editor.interface_handler.window.set_title(get_title())
	else:
		open()


func get_title() -> String:
	return "%s - %s" % [title, _entry.display_name] if _entry else title


func _build() -> void:
	for child: Node in container.get_children():
		child.queue_free()
	_bindings.clear()
	var sample: GameObject = ObjectRegistry.spawn(ObjectData.create(_entry.id), GameObject.Context.EDITOR)
	if sample.has_flag(GameObject.Flag.ROTATABLE) or sample.has_flag(GameObject.Flag.SCALABLE):
		_add_header("Transform")
	if sample.has_flag(GameObject.Flag.ROTATABLE):
		_add_row(LDToolHandler.ROTATION_KEY, 0.0, "Rotation", {"type": TYPE_FLOAT})
	if sample.has_flag(GameObject.Flag.SCALABLE):
		_add_row(LDToolHandler.SCALE_KEY, Vector2.ONE, "Scale", {"type": TYPE_VECTOR2, "widget": &"vector2_range", "hint_string": "0.25,4,0.05", "format": "%.2fx"})
	var section: StringName = &""
	var first: bool = true
	for property: ObjectProperty in sample.properties:
		if not LDInspector.is_editable(property):
			continue
		
		if first or property.group != section:
			first = false
			section = property.group
			_add_header(String(section) if not section.is_empty() else "Properties")
		_add_row(property.key, property.coerce(null), property.get_label(), property.to_info())
	
	sample.free()
	empty_label.visible = _bindings.is_empty()
	refit()


func _add_header(text: String) -> void:
	var header: Label = section_scene.instantiate()
	header.text = text
	container.add_child(header)


func _add_row(key: StringName, default: Variant, label: String, info: Dictionary) -> void:
	var binding: PropertyBinding = PropertyBinding.new(
		func() -> Variant: return _values.get(key, default),
		_store.bind(key, default),
		label, info)
	var row: Control = LDInspector.make_row(binding, default, reset_icon)
	if row:
		_bindings.append(binding)
		container.add_child(row)


func _store(value: Variant, key: StringName, default: Variant) -> void:
	if value == default:
		_values.erase(key)
	else:
		_values.set(key, value)
	
	for binding: PropertyBinding in _bindings:
		binding.refresh()
	if _on_change.is_valid():
		_on_change.call()
