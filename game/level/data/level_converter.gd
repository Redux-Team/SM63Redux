class_name LevelConverter

const LEGACY_VERSION: int = 1
const DEFAULT_AREA_NAME: String = "Area 1"
const TRANSFORM_KEYS: PackedStringArray = ["position", "rotation", "scale"]
const SHAPE_KEYS: PackedStringArray = [
	"t_size_x",
	"t_size_y",
	"b_size_x",
	"b_size_y",
	"path_points",
]
const RENAMED: Dictionary[String, String] = {
	"rotation:arrow": "arrow_rotation",
}
const COLLISION_MODES: Dictionary[String, int] = {
	"Solid": 0,
	"Semisolid": 1,
	"None": 2,
}
const BLOCK_DEFAULT: int = 32
const LAYER_DISTANCE_MIN: float = -0.8
const LAYER_DISTANCE_MAX: float = 9.0


static func is_legacy(dict: Dictionary) -> bool:
	var version: Variant = dict.get("version")
	if version == null:
		return dict.has("areas") or dict.has("layers")
	
	return int(version) == LEGACY_VERSION


static func convert(source: Dictionary) -> Dictionary:
	var legacy: Dictionary = _normalize(source)
	var editor: Dictionary = legacy.get("editor", {})
	var areas: Array[Dictionary] = []
	for area: Variant in legacy.get("areas", []):
		if area is Dictionary:
			areas.append(_convert_area(area, editor))
	if areas.is_empty():
		areas.append(AreaData.create(DEFAULT_AREA_NAME).to_dict())
	
	_expand_stamps(legacy.get("stamps", []), areas, legacy.get("areas", []))
	var extras: Dictionary = {}
	for key: String in ["stamps", "tags", "scenarios", "custom_music"]:
		var value: Variant = legacy.get(key)
		if (
				value is Dictionary and not (value as Dictionary).is_empty()
				or value is Array and not (value as Array).is_empty()
		):
			extras.get_or_add("v1", {}).set(key, value)
	
	return {
		"version": LevelData.VERSION,
		"name": "",
		"areas": areas,
		"editor": {
			"active_area": int(editor.get("active_area", 0)),
			"hotbar": _convert_hotbar(editor.get("hotbar", [])),
		},
		"extras": extras,
	}


static func _normalize(source: Dictionary) -> Dictionary:
	var legacy: Dictionary = source.duplicate(true)
	if not legacy.has("areas"):
		var area: Dictionary = {
			"name": DEFAULT_AREA_NAME,
			"layers": legacy.get("layers", []),
		}
		var editor: Dictionary = legacy.get("editor", {})
		for key: String in ["camera_position", "camera_zoom", "active_layer"]:
			if editor.has(key):
				area[key] = editor[key]
		legacy["areas"] = [area]
	
	return legacy


static func _convert_area(area: Dictionary, editor: Dictionary) -> Dictionary:
	var zoom: Variant = area.get("camera_zoom", 1.0)
	var layers: Array[Dictionary] = []
	for layer: Variant in area.get("layers", []):
		if layer is Dictionary:
			layers.append(_convert_layer(layer))
	
	return {
		"uuid": StringName(Packer.generate_uuid()),
		"name": str(area.get("name", DEFAULT_AREA_NAME)),
		"camera_position": _vec(area.get("camera_position", Vector2.ZERO)),
		"camera_zoom": (_vec(zoom).x if zoom is Array or zoom is Vector2 else float(zoom)),
		"active_layer": int(area.get("active_layer", 0)),
		"background": _convert_background(area.get("background", editor.get("background", {}))),
		"music": (
				area.get("music", {})
				if area.get("music") is Dictionary
				else { "subtracks": area.get("music", []) }
		),
		"layer_groups": [],
		"layers": layers,
	}


static func _convert_layer(layer: Dictionary) -> Dictionary:
	var objects: Array[Dictionary] = []
	for object: Variant in layer.get("objects", []):
		var converted: Dictionary = _convert_object(object) if object is Dictionary else {}
		if not converted.is_empty():
			objects.append(converted)
	
	return {
		"uuid": StringName(Packer.generate_uuid()),
		"index": int(layer.get("layer_index", layer.get("index", 0))),
		"name": str(layer.get("layer_name", layer.get("name", ""))),
		"distance": _layer_distance(layer),
		"modulation": _color(layer.get("modulation", Color.WHITE)),
		"is_decoration": bool(layer.get("is_decoration", false)),
		"enabled": true,
		"group": &"",
		"objects": objects,
	}


static func _layer_distance(layer: Dictionary) -> float:
	var legacy: Variant = layer.get("layer_scale", layer.get("parallax_scale"))
	if legacy != null and not layer.get("is_decoration", false):
		return clampf(
				1.0 / maxf(_vec(legacy).x, 0.01) - 1.0,
				LAYER_DISTANCE_MIN,
				LAYER_DISTANCE_MAX,
		)
	
	return clampf(float(layer.get("distance", 0.0)), LAYER_DISTANCE_MIN, LAYER_DISTANCE_MAX)


static func _convert_object(object: Dictionary, offset: Vector2 = Vector2.ZERO) -> Dictionary:
	var id: StringName = StringName(str(object.get("object_id", object.get("id", ""))))
	var entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(id)
	if entry == null:
		push_warning("LevelConverter: dropped unknown object '%s'." % id)
		return {}
	
	var properties: Dictionary = \
			object.get("properties", {}) if object.get("properties") is Dictionary else {}
	var values: Dictionary[StringName, Variant] = {}
	for key: Variant in properties:
		var name: String = str(key)
		if TRANSFORM_KEYS.has(name) or SHAPE_KEYS.has(name):
			continue
		
		var value: Variant = _convert_value(name, properties[key])
		if value != null:
			values[StringName(RENAMED.get(name, name))] = value
	
	if id == &"moving_platform" and properties.has("t_size_x"):
		values[&"platform_width"] = int(properties["t_size_x"])
	
	return {
		"uuid": StringName(Packer.generate_uuid()),
		"id": id,
		"position": _vec(object.get("position", properties.get("position", Vector2.ZERO))) + offset,
		"rotation": deg_to_rad(float(properties.get("rotation", 0.0))),
		"scale": _vec(properties.get("scale", Vector2.ONE)),
		"values": values,
		"shape": _convert_shape(entry.get_shape_kind(), object, properties),
	}


static func _convert_value(key: String, value: Variant) -> Variant:
	if key == "collision_mode":
		return COLLISION_MODES.get(str(value))
	if value is Array and ((value as Array).size() == 2 or (value as Array).size() == 4):
		return Packer.deserialize_json_variant(value)
	
	return value


static func _convert_shape(
		kind: ObjectShape.Kind,
		object: Dictionary,
		properties: Dictionary,
) -> Dictionary:
	match kind:
		ObjectShape.Kind.POLYGON:
			return _convert_polygon(object)
		ObjectShape.Kind.PATH:
			var points: PackedVector2Array = \
					Packer.to_packed_vec2(properties.get("path_points", PackedVector2Array()))
			return { "points": points } if points.size() >= PathShape.MIN_POINTS else {}
		ObjectShape.Kind.TELESCOPING:
			var units: Variant = properties.get("t_size_x", properties.get("t_size_y"))
			return { "units": int(units) } if units != null else {}
		ObjectShape.Kind.BLOCK:
			return {
				"size": Vector2(
						int(properties.get("b_size_x", BLOCK_DEFAULT)),
						int(properties.get("b_size_y", BLOCK_DEFAULT)),
				),
			}
	
	return {}


static func _convert_polygon(object: Dictionary) -> Dictionary:
	var outer: PackedVector2Array = Packer.to_packed_vec2(object.get("polygon_points", []))
	if outer.size() < PolygonShape.MIN_POINTS:
		return {}
	
	var rings: Array[PackedVector2Array] = [outer]
	for hole: Variant in object.get("polygon_holes", []):
		var points: PackedVector2Array = Packer.to_packed_vec2(hole)
		if points.size() >= PolygonShape.MIN_POINTS:
			rings.append(points)
	
	var forced: Dictionary = \
			object.get("topline_forced", {}) if object.get("topline_forced") is Dictionary else {}
	var toplines: Array[Vector3i] = []
	for ring: int in rings.size():
		var points: PackedVector2Array = rings[ring]
		for edge: int in points.size():
			var key: String = _midpoint_key(points[edge], points[(edge + 1) % points.size()])
			if forced.has(key):
				toplines.append(Vector3i(ring, edge, 1 if forced[key] else 0))
	
	return { "outer": outer, "holes": rings.slice(1), "toplines": toplines }


static func _midpoint_key(a: Vector2, b: Vector2) -> String:
	var middle: Vector2 = (a + b) * 0.5
	return "%d,%d" % [roundi(middle.x), roundi(middle.y)]


static func _expand_stamps(stamps: Variant, areas: Array[Dictionary], legacy_areas: Array) -> void:
	if not stamps is Array:
		return
	
	for i: int in areas.size():
		var area_name: String = (
				str((legacy_areas[i] as Dictionary).get("name", ""))
				if i < legacy_areas.size() and legacy_areas[i] is Dictionary
				else ""
		)
		for stamp: Variant in stamps:
			if not stamp is Dictionary:
				continue
			
			for instance: Dictionary in _stamp_instances(
					(stamp as Dictionary).get("instances", {}),
					area_name,
			):
				var base: Vector2 = _vec(instance.get("position", Vector2.ZERO))
				for entry: Variant in (stamp as Dictionary).get("objects", []):
					if not entry is Dictionary:
						continue
					
					var converted: Dictionary = _convert_object(
							entry,
							(
									base
									+ _vec((entry as Dictionary).get("local_offset", Vector2.ZERO))
									- _vec((entry as Dictionary).get("position", Vector2.ZERO))
							),
					)
					if not converted.is_empty():
						var index: int = (
								int(instance.get("layer_index", 0))
								+ int((entry as Dictionary).get("layer_offset", 0))
						)
						(_layer_for(areas[i], index)["objects"] as Array).append(converted)


static func _stamp_instances(instances: Variant, area_name: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var source: Array = []
	if instances is Dictionary:
		source = (instances as Dictionary).get(area_name, [])
	elif instances is Array:
		source = (instances as Array).filter(
				func(instance: Variant) -> bool:
					return (
						instance is Dictionary
						and str(
							(instance as Dictionary).get("area_name", area_name)
						) in ["", area_name]
					)
		)
	for instance: Variant in source:
		if instance is Dictionary:
			result.append(instance)
	
	return result


static func _layer_for(area: Dictionary, index: int) -> Dictionary:
	for layer: Dictionary in area["layers"]:
		if layer["index"] == index:
			return layer
	
	var created: Dictionary = _convert_layer({ "layer_index": index })
	(area["layers"] as Array).append(created)
	return created


static func _convert_background(background: Variant) -> Dictionary:
	if not background is Dictionary:
		return {}
	
	var preset: String = str((background as Dictionary).get("preset", ""))
	if preset != "Custom" and not preset.is_empty():
		var id: StringName = StringName(preset.to_snake_case())
		if id == LevelBackground.DEFAULT_PRESET or not LevelBackground.get_preset_ids().has(id):
			return {}
		return LevelBackground.load_preset(id)
	
	var data: Dictionary = (background as Dictionary).get("data", background)
	var target: Background = Background.new()
	target.background_texture = _backdrop(data)
	var layers: Array[BackgroundLayer] = []
	for source: Variant in data.get("layers", []):
		if source is Dictionary:
			layers.append(_background_layer(source))
	target.layers = layers
	var encoded: Dictionary = LevelBackground.encode(target)
	target.free()
	return encoded


static func _backdrop(data: Dictionary) -> Texture2D:
	var gradient: Gradient = Gradient.new()
	if int(data.get("backdrop_type", 0)) == 1:
		gradient.set_color(0, _color(data.get("gradient_top", Color.BLACK)))
		gradient.set_color(1, _color(data.get("gradient_bottom", Color.BLACK)))
	else:
		gradient.remove_point(1)
		gradient.set_color(0, _color(data.get("solid_color", Color.BLACK)))
	
	var texture: GradientTexture2D = GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 64
	texture.fill_to = Vector2(0.0, 1.0)
	return texture


static func _background_layer(source: Dictionary) -> BackgroundLayer2D:
	var layer: BackgroundLayer2D = BackgroundLayer2D.new()
	layer.layer_name = str(source.get("display_name", ""))
	var path: String = str(source.get("texture", ""))
	if not path.is_empty() and ResourceLoader.exists(path):
		layer.texture = load(path) as Texture2D
	layer.scroll_rate = Vector2.ONE * float(source.get("parallax", 0.5))
	if source.get("custom_color", false):
		layer.modulate = _color(source.get("modulate", Color.WHITE))
	layer.scroll_offset = _vec(source.get("offset", Vector2.ZERO))
	layer.autoscroll = _vec(source.get("autoscroll", Vector2.ZERO))
	layer.repeat_mode = (
			BackgroundLayer.RepeatMode.INDEFINITE_X
			if source.get("repeat", true)
			else BackgroundLayer.RepeatMode.NONE
	)
	layer.anchor = (
			BackgroundLayer2D.AnchorPos.TOP
			if int(source.get("anchor", 0)) == 1
			else BackgroundLayer2D.AnchorPos.BOTTOM
	)
	return layer


static func _convert_hotbar(slots: Variant) -> Array:
	var ids: Array = []
	if not slots is Array:
		return ids
	
	for slot: Variant in slots:
		var kind: String = str((slot as Dictionary).get("kind", "")) if slot is Dictionary else ""
		ids.append(str((slot as Dictionary).get("object_id", "")) if kind == "object" else "")
	
	return ids


static func _vec(value: Variant) -> Vector2:
	if value is Vector2 or value is Vector2i:
		return Vector2(value)
	
	return Packer.array_to_vec2(value)


static func _color(value: Variant) -> Color:
	if value is Color:
		return value
	if value is String:
		return Color.from_string(value, Color.WHITE)
	
	return Packer.array_to_color(value)
