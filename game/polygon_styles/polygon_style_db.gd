class_name PolygonStyleDB

## Registry of terrain/polygon style presets. Presets are plain style resources dropped into the
## directories below; add or tweak one there and it shows up in every terrain's style dropdown
## automatically (mirrors [LDBackgroundDB]). Selections are saved by style_name, so adding or
## reordering presets never breaks existing levels.

const BASE_DIR: String = "res://game/db/Polygon/Styles/Base"
const TOPLINE_DIR: String = "res://game/db/Polygon/Styles/Topline"
const DECORATION_DIR: String = "res://game/db/Polygon/Styles/Decoration"


static var _base: Array[PolygonBaseStyle] = []
static var _topline: Array[PolygonToplineStyle] = []
static var _decoration: Array[PolygonDecorationStyle] = []
static var _loaded: bool = false


static func get_base_styles() -> Array[PolygonBaseStyle]:
	_ensure_loaded()
	return _base


static func get_topline_styles() -> Array[PolygonToplineStyle]:
	_ensure_loaded()
	return _topline


static func get_decoration_styles() -> Array[PolygonDecorationStyle]:
	_ensure_loaded()
	return _decoration


static func get_base_style(style_name: String) -> PolygonBaseStyle:
	for style: PolygonBaseStyle in get_base_styles():
		if style.style_name == style_name:
			return style
	return null


static func get_topline_style(style_name: String) -> PolygonToplineStyle:
	for style: PolygonToplineStyle in get_topline_styles():
		if style.style_name == style_name:
			return style
	return null


static func get_decoration_style(style_name: String) -> PolygonDecorationStyle:
	for style: PolygonDecorationStyle in get_decoration_styles():
		if style.style_name == style_name:
			return style
	return null


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	for res: Resource in _load_dir(BASE_DIR):
		if res is PolygonBaseStyle:
			_base.append(res)
	for res: Resource in _load_dir(TOPLINE_DIR):
		if res is PolygonToplineStyle:
			_topline.append(res)
	for res: Resource in _load_dir(DECORATION_DIR):
		if res is PolygonDecorationStyle:
			_decoration.append(res)
	_base.sort_custom(func(a: PolygonBaseStyle, b: PolygonBaseStyle) -> bool: return a.style_name < b.style_name)
	_topline.sort_custom(func(a: PolygonToplineStyle, b: PolygonToplineStyle) -> bool: return a.style_name < b.style_name)
	_decoration.sort_custom(func(a: PolygonDecorationStyle, b: PolygonDecorationStyle) -> bool: return a.style_name < b.style_name)


static func _load_dir(path: String) -> Array[Resource]:
	var result: Array[Resource] = []
	var dir: DirAccess = DirAccess.open(path)
	if not dir:
		return result
	dir.list_dir_begin()
	var file_name: String = dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".tres"):
			var res: Resource = load(path.path_join(file_name))
			if res:
				result.append(res)
		file_name = dir.get_next()
	return result
