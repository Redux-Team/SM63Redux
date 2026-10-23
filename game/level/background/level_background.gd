@tool
class_name LevelBackground
extends Background

const PRESETS_ROOT: String = "res://game/backgrounds/"
const DEFAULT_PRESET: StringName = &"mushroom_hills"

static var _presets: Dictionary[StringName, Dictionary] = {}


static func get_preset_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for file: String in ResourceLoader.list_directory(PRESETS_ROOT):
		if file.get_extension() == "tscn":
			ids.append(StringName(file.get_basename()))
	
	return ids


static func get_preset_name(id: StringName) -> String:
	return String(id).capitalize()


static func load_preset(id: StringName) -> Dictionary:
	if not _presets.has(id):
		var scene: PackedScene = load(PRESETS_ROOT.path_join("%s.tscn" % id)) as PackedScene
		var root: Background = scene.instantiate() as Background if scene else null
		_presets[id] = encode(root) if root else {}
		if root:
			root.free()
	
	return (_presets[id] as Dictionary).duplicate(true)


static func resolve(data: Dictionary) -> Dictionary:
	return data if not data.is_empty() else load_preset(DEFAULT_PRESET)


static func encode(source: Background) -> Dictionary:
	return {
		"texture": ResourceCodec.encode(source.background_texture),
		"autoscroll": source.autoscroll,
		"follow_camera": source.follow_camera,
		"layers": ResourceCodec.encode(source.layers),
	}


static func decode_layers(data: Dictionary) -> Array[BackgroundLayer]:
	var decoded: Array[BackgroundLayer] = []
	for item: Variant in ResourceCodec.decode(data.get("layers", [])):
		if item is BackgroundLayer:
			decoded.append(item)
	
	return decoded


func apply_data(data: Dictionary) -> void:
	var resolved: Dictionary = resolve(data)
	background_texture = ResourceCodec.decode(resolved.get("texture")) as Texture2D
	autoscroll = resolved.get("autoscroll", Vector2.ZERO)
	follow_camera = resolved.get("follow_camera", true)
	layers = decode_layers(resolved)
