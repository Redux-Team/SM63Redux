extends PropertyWidget

const EXTENSIONS: PackedStringArray = ["png", "svg", "webp", "jpg"]

@export var label: Label
@export var preview: TextureRect
@export var option_button: OptionButton

var _textures: Array[Texture2D] = []


func _ready() -> void:
	option_button.item_selected.connect(func(index: int) -> void: _commit(_textures.get(index)))


func _name(widget_name: String) -> void:
	label.text = widget_name


func _info(widget_info: Dictionary) -> void:
	option_button.clear()
	_textures.clear()
	_add_item("None", null)
	var root: String = widget_info.get("root", "res://")
	for path: String in _collect(root):
		_add_item(path.get_file().get_basename().capitalize(), load(path) as Texture2D)


func _value(widget_value: Variant) -> void:
	var texture: Texture2D = widget_value as Texture2D
	preview.texture = texture
	var index: int = _textures.find(texture)
	if index < 0:
		_add_item("Custom", texture)
		index = _textures.size() - 1
	option_button.select(index)


func _add_item(text: String, texture: Texture2D) -> void:
	option_button.add_item(text)
	_textures.append(texture)


static func _collect(directory: String) -> PackedStringArray:
	var paths: PackedStringArray = []
	for file: String in ResourceLoader.list_directory(directory):
		if file.ends_with("/"):
			paths.append_array(_collect(directory.path_join(file)))
		elif EXTENSIONS.has(file.get_extension()):
			paths.append(directory.path_join(file))
	
	return paths
