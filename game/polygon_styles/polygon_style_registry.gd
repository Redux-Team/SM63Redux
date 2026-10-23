class_name PolygonStyleRegistry

enum Kind {
	BASE,
	TOPLINE,
	DECORATION,
}

const ROOT: String = "res://game/polygon_styles/presets/"
const FOLDERS: Dictionary[Kind, String] = {
	Kind.BASE: "base",
	Kind.TOPLINE: "topline",
	Kind.DECORATION: "decoration",
}

static var _styles: Dictionary[Kind, Array] = {}


static func get_styles(kind: Kind) -> Array[Resource]:
	if not _styles.has(kind):
		var styles: Array[Resource] = []
		var folder: String = ROOT.path_join(FOLDERS[kind])
		for file: String in ResourceLoader.list_directory(folder):
			if file.get_extension() == "tres":
				styles.append(load(folder.path_join(file)))
		styles.sort_custom(
				func(a: Resource, b: Resource) -> bool:
					return (String(a.get(&"style_name")) < String(b.get(&"style_name")))
		)
		_styles[kind] = styles
	
	var result: Array[Resource] = []
	result.assign(_styles[kind])
	return result


static func get_names(kind: Kind) -> PackedStringArray:
	var names: PackedStringArray = []
	for style: Resource in get_styles(kind):
		names.append(style.get(&"style_name"))
	
	return names


static func find(kind: Kind, style_name: String) -> Resource:
	if style_name.is_empty():
		return null
	
	for style: Resource in get_styles(kind):
		if style.get(&"style_name") == style_name:
			return style
	
	return null
