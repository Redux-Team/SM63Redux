static func run_test() -> void:
	assert(LevelConverter.is_legacy({ "areas": [] }))
	assert(LevelConverter.is_legacy({ "layers": [] }))
	assert(LevelConverter.is_legacy({ "version": 1 }))
	assert(LevelConverter.is_legacy({ "version": 1.0 }))
	assert(not LevelConverter.is_legacy({}))
	assert(not LevelConverter.is_legacy({ "version": LevelData.VERSION, "areas": [] }))
	
	var empty: Dictionary = LevelConverter.convert({ "version": 1 })
	assert(empty.get("version") == LevelData.VERSION)
	assert((empty.get("areas") as Array).size() == 1)
	assert(
			((empty.get("areas") as Array).front() as Dictionary).get("name")
			== LevelConverter.DEFAULT_AREA_NAME
	)
	assert(empty.get("editor") == { "active_area": 0, "hotbar": [] })
	assert((empty.get("extras") as Dictionary).is_empty())
	assert(LevelData.from_dict(empty) != null)
	
	var flat: Dictionary = LevelConverter.convert({
		"layers": [
			{
				"layer_index": 2,
				"layer_name": "Back",
				"objects": [{ "object_id": "goomba", "position": [10, 20] }],
			},
		],
		"editor": {
			"camera_position": [64, 128],
			"camera_zoom": [2, 2],
			"active_layer": 2,
			"active_area": 0,
		},
	})
	var flat_area: Dictionary = (flat.get("areas") as Array).front()
	assert(flat_area.get("name") == LevelConverter.DEFAULT_AREA_NAME)
	assert(flat_area.get("camera_position") == Vector2(64.0, 128.0))
	assert(flat_area.get("camera_zoom") == 2.0)
	assert(flat_area.get("active_layer") == 2)
	var flat_layer: Dictionary = (flat_area.get("layers") as Array).front()
	assert(flat_layer.get("index") == 2)
	assert(flat_layer.get("name") == "Back")
	assert(flat_layer.get("enabled") == true)
	var goomba: Dictionary = (flat_layer.get("objects") as Array).front()
	assert(goomba.get("id") == &"goomba")
	assert(goomba.get("position") == Vector2(10.0, 20.0))
	
	var areas: Dictionary = LevelConverter.convert({
		"version": 1,
		"areas": [
			{
				"name": "Zoomed",
				"camera_zoom": 0.5,
				"music": [3, 4],
				"layers": [
					"junk",
					{
						"index": 1,
						"name": "Named",
						"modulation": "#ff000080",
						"distance": 20.0,
					},
				],
			},
			{"name": "Scaled", "music": { "track": "hub" }, "layers": [
				{ "layer_scale": [0.5, 0.5] },
				{ "parallax_scale": [100.0, 100.0] },
				{
					"layer_scale": [0.5, 0.5],
					"is_decoration": true,
					"distance": -3.0,
				},
				{ "modulation": [0.0, 0.5, 1.0, 1.0] },
			]},
			"junk",
		],
		"editor": { "active_area": 1 },
	})
	var converted_areas: Array = areas["areas"]
	assert(converted_areas.size() == 2)
	assert((areas.get("editor") as Dictionary).get("active_area") == 1)
	var zoomed: Dictionary = converted_areas.front()
	assert(zoomed.get("camera_zoom") == 0.5)
	assert(zoomed.get("music") == { "subtracks": [3, 4] })
	var named: Dictionary = (zoomed.get("layers") as Array).front()
	assert((zoomed.get("layers") as Array).size() == 1)
	assert(named.get("index") == 1)
	assert(named.get("name") == "Named")
	assert((named.get("modulation") as Color).is_equal_approx(Color(1.0, 0.0, 0.0, 128.0 / 255.0)))
	assert(named.get("distance") == LevelConverter.LAYER_DISTANCE_MAX)
	var scaled: Dictionary = converted_areas.back()
	assert(scaled.get("music") == { "track": "hub" })
	var scaled_layers: Array = scaled["layers"]
	assert(is_equal_approx((scaled_layers[0] as Dictionary)["distance"], 1.0))
	assert((scaled_layers[1] as Dictionary).get("distance") == LevelConverter.LAYER_DISTANCE_MIN)
	assert((scaled_layers[2] as Dictionary).get("distance") == LevelConverter.LAYER_DISTANCE_MIN)
	assert((scaled_layers[2] as Dictionary).get("is_decoration") == true)
	assert((scaled_layers[3] as Dictionary).get("modulation") == Color(0.0, 0.5, 1.0, 1.0))
	
	var objects: Dictionary = LevelConverter.convert({
		"version": 1,
		"areas": [{"layers": [{"objects": [
			"junk",
			{ "object_id": "missing_object_id" },
			{
				"id": "arrow_sign",
				"properties": {
					"position": [5, 6],
					"rotation": 90.0,
					"scale": [2, 3],
					"rotation:arrow": 45.0,
					"tint": [1.0, 0.0, 0.0, 1.0],
					"offset": [7, 8],
					"label": "hello",
				},
			},
			{
				"object_id": "terrain_grass",
				"properties": { "collision_mode": "Semisolid" },
				"polygon_points": [[0, 0], [64, 0], [64, 64], [0, 64]],
			},
			{
				"object_id": "terrain_grass",
				"properties": { "collision_mode": "Unknown" },
			},
			{ "object_id": "moving_platform", "properties": { "t_size_x": 3 } },
		]}]}],
	})
	var converted: Array = (
			((objects.get("areas") as Array).front() as Dictionary).get("layers")
			as Array
	).front().get("objects")
	assert(converted.size() == 4)
	var arrow: Dictionary = converted[0]
	var arrow_values: Dictionary = arrow["values"]
	assert(arrow.get("position") == Vector2(5.0, 6.0))
	assert(is_equal_approx(arrow["rotation"], PI * 0.5))
	assert(arrow.get("scale") == Vector2(2.0, 3.0))
	assert(arrow_values.get(&"arrow_rotation") == 45.0)
	assert(not arrow_values.has(&"rotation:arrow"))
	assert(not arrow_values.has(&"position"))
	assert(not arrow_values.has(&"rotation"))
	assert(not arrow_values.has(&"scale"))
	assert(arrow_values.get(&"tint") == Color(1.0, 0.0, 0.0, 1.0))
	assert(arrow_values.get(&"offset") == Vector2(7.0, 8.0))
	assert(arrow_values.get(&"label") == "hello")
	assert((converted[1] as Dictionary).get("values").get(&"collision_mode") == 1)
	assert(not ((converted[2] as Dictionary).get("values") as Dictionary).has(&"collision_mode"))
	assert(((converted[2] as Dictionary).get("shape") as Dictionary).is_empty())
	assert((converted[3] as Dictionary).get("values").get(&"platform_width") == 3)
	
	var shapes: Dictionary = LevelConverter.convert({
		"version": 1,
		"areas": [{"layers": [{"objects": [
			{
				"object_id": "terrain_grass",
				"polygon_points": [[0, 0], [64, 0], [64, 64], [0, 64]],
				"polygon_holes": [
					[[16, 16], [48, 16], [48, 48], [16, 48]],
					[[0, 0], [1, 1]],
				],
				"topline_forced": {
					"32,0": true,
					"32,64": false,
					"32,16": true,
					"99,99": true,
				},
			},
			{
				"object_id": "tall_mushroom",
				"properties": {
					"path_points": "[(0, 0), (0, -64), (16, -96)]",
				},
			},
			{
				"object_id": "tall_mushroom",
				"properties": { "path_points": [[0, 0]] },
			},
			{ "object_id": "wooden_platform", "properties": { "t_size_x": 5 } },
			{ "object_id": "wooden_platform" },
			{ "object_id": "spinning_block", "properties": { "b_size_x": 64 } },
			{ "object_id": "goomba", "properties": { "b_size_x": 64 } },
		]}]}],
	})
	var shaped: Array = (
			((shapes.get("areas") as Array).front() as Dictionary).get("layers")
			as Array
	).front().get("objects")
	var polygon: Dictionary = (shaped[0] as Dictionary)["shape"]
	assert(
			polygon.get("outer")
			== PackedVector2Array([Vector2(0, 0), Vector2(64, 0), Vector2(64, 64), Vector2(0, 64)])
	)
	assert((polygon.get("holes") as Array).size() == 1)
	assert(
			(polygon.get("holes") as Array).front()
			== PackedVector2Array(
					[Vector2(16, 16), Vector2(48, 16), Vector2(48, 48), Vector2(16, 48)]
			)
	)
	var toplines: Array = polygon["toplines"]
	assert(toplines.size() == 3)
	assert(toplines.has(Vector3i(0, 0, 1)))
	assert(toplines.has(Vector3i(0, 2, 0)))
	assert(toplines.has(Vector3i(1, 0, 1)))
	assert(
			(shaped[1] as Dictionary).get("shape")
			== {
				"points": PackedVector2Array([Vector2(0, 0), Vector2(0, -64), Vector2(16, -96)]),
			}
	)
	assert(((shaped[2] as Dictionary).get("shape") as Dictionary).is_empty())
	assert((shaped[3] as Dictionary).get("shape") == { "units": 5 })
	assert(((shaped[4] as Dictionary).get("shape") as Dictionary).is_empty())
	assert(
			(shaped[5] as Dictionary).get("shape")
			== { "size": Vector2(64.0, LevelConverter.BLOCK_DEFAULT) }
	)
	assert(((shaped[6] as Dictionary).get("shape") as Dictionary).is_empty())
	assert(not ((shaped[6] as Dictionary).get("values") as Dictionary).has(&"b_size_x"))
	
	var stamp_objects: Array = [
		{
			"object_id": "yellow_coin",
			"position": [100, 100],
			"local_offset": [8, 0],
		},
		{ "object_id": "goomba", "position": [0, 0], "layer_offset": 2 },
		"junk",
		{ "object_id": "missing_object_id" },
	]
	var stamped: Dictionary = LevelConverter.convert({
		"version": 1,
		"areas": [
			{ "name": "Main", "layers": [{ "layer_index": 0 }] },
			{ "name": "Side", "layers": [] },
		],
		"stamps": [
			{
				"objects": stamp_objects,
				"instances": {
					"Main": [{ "position": [200, 50], "layer_index": 0 }],
					"Side": [],
				},
			},
			{
				"objects": stamp_objects,
				"instances": [
					{
						"position": [0, 0],
						"area_name": "Side",
						"layer_index": 1,
					},
					{ "position": [10, 10], "area_name": "Other" },
				],
			},
			"junk",
		],
		"tags": ["platformer"],
		"scenarios": [],
		"custom_music": { "a": 1 },
	})
	var main: Dictionary = (stamped.get("areas") as Array)[0]
	var main_layers: Array = main["layers"]
	assert(main_layers.size() == 2)
	var base_objects: Array = (main_layers[0] as Dictionary)["objects"]
	assert(base_objects.size() == 1)
	assert((base_objects.front() as Dictionary).get("id") == &"yellow_coin")
	assert((base_objects.front() as Dictionary).get("position") == Vector2(208.0, 50.0))
	var offset_layer: Dictionary = main_layers[1]
	assert(offset_layer.get("index") == 2)
	assert(
			((offset_layer.get("objects") as Array).front() as Dictionary).get("position")
			== Vector2(200.0, 50.0)
	)
	var side_layers: Array = ((stamped.get("areas") as Array)[1] as Dictionary)["layers"]
	assert(side_layers.size() == 2)
	assert(
			side_layers.any(
					func(layer: Dictionary) -> bool: return (
							layer.get("index") == 1
							and (layer.get("objects") as Array).size() == 1
					)
			)
	)
	assert(
			side_layers.any(
					func(layer: Dictionary) -> bool: return (
							layer.get("index") == 3
							and (layer.get("objects") as Array).size() == 1
					)
			)
	)
	var extras: Dictionary = (stamped.get("extras") as Dictionary)["v1"]
	assert(extras.has("stamps"))
	assert(extras.get("tags") == ["platformer"])
	assert(extras.get("custom_music") == { "a": 1 })
	assert(not extras.has("scenarios"))
	
	var hotbar: Dictionary = LevelConverter.convert({
		"version": 1,
		"editor": {
			"hotbar": [
				{ "kind": "object", "object_id": "goomba" },
				{ "kind": "tool", "object_id": "select" },
				"junk",
			],
		},
	})
	assert((hotbar.get("editor") as Dictionary).get("hotbar") == ["goomba", "", ""])
	assert(
			(
					LevelConverter.convert(
							{ "version": 1, "editor": { "hotbar": "junk" } }
					).get("editor") as Dictionary
			).get("hotbar")
			== []
	)
	
	var preset: Dictionary = _background(
			LevelConverter.convert({
				"version": 1,
				"areas": [{ "background": { "preset": "Snowy Peaks" } }],
			})
	)
	assert(preset == LevelBackground.load_preset(&"snowy_peaks"))
	assert(not preset.is_empty())
	assert(
			_background(
					LevelConverter.convert({
						"version": 1,
						"areas": [
							{ "background": { "preset": "Mushroom Hills" } },
						],
					})
			).is_empty()
	)
	assert(
			_background(
					LevelConverter.convert({
						"version": 1,
						"areas": [{ "background": { "preset": "Nowhere" } }],
					})
			).is_empty()
	)
	assert(
			_background(
					LevelConverter.convert({
						"version": 1,
						"areas": [{ "background": "junk" }],
					})
			).is_empty()
	)
	var fallback: Dictionary = _background(
			LevelConverter.convert({
				"version": 1,
				"editor": { "background": { "preset": "Snowy Peaks" } },
				"areas": [{}],
			})
	)
	assert(fallback == preset)
	
	var custom: Dictionary = _background(
			LevelConverter.convert({
				"version": 1,
				"areas": [{"background": {
					"preset": "Custom",
					"data": {
						"backdrop_type": 1,
						"gradient_top": "#000000",
						"gradient_bottom": "#ffffff",
						"layers": [
							{
								"display_name": "Hills",
								"parallax": 0.25,
								"offset": [0, 10],
								"autoscroll": [5, 0],
								"repeat": false,
								"anchor": 1,
								"custom_color": true,
								"modulate": "#ff0000",
							},
							{ "display_name": "Clouds" },
							"junk",
						],
					},
				}}],
			})
	)
	assert(custom.has("texture"))
	var layers: Array[BackgroundLayer] = LevelBackground.decode_layers(custom)
	assert(layers.size() == 2)
	var hills: BackgroundLayer2D = layers.front() as BackgroundLayer2D
	assert(hills.layer_name == "Hills")
	assert(hills.scroll_rate == Vector2(0.25, 0.25))
	assert(hills.scroll_offset == Vector2(0.0, 10.0))
	assert(hills.autoscroll == Vector2(5.0, 0.0))
	assert(hills.repeat_mode == BackgroundLayer.RepeatMode.NONE)
	assert(hills.anchor == BackgroundLayer2D.AnchorPos.TOP)
	assert(hills.modulate == Color.RED)
	var clouds: BackgroundLayer2D = layers.back() as BackgroundLayer2D
	assert(clouds.scroll_rate == Vector2(0.5, 0.5))
	assert(clouds.repeat_mode == BackgroundLayer.RepeatMode.INDEFINITE_X)
	assert(clouds.anchor == BackgroundLayer2D.AnchorPos.BOTTOM)
	var backdrop: GradientTexture2D = ResourceCodec.decode(custom["texture"]) as GradientTexture2D
	assert(backdrop != null)
	assert(backdrop.gradient.get_point_count() == 2)
	assert(backdrop.gradient.get_color(0) == Color.BLACK)
	assert(backdrop.gradient.get_color(1) == Color.WHITE)
	var solid: Dictionary = _background(
			LevelConverter.convert({
				"version": 1,
				"areas": [{ "background": { "solid_color": "#00ff00" } }],
			})
	)
	var solid_backdrop: GradientTexture2D = \
			ResourceCodec.decode(solid.get("texture")) as GradientTexture2D
	assert(solid_backdrop.gradient.get_point_count() == 1)
	assert(solid_backdrop.gradient.get_color(0) == Color.GREEN)
	
	var full: Dictionary = LevelConverter.convert({
		"version": 1,
		"areas": [
			{
				"name": "Roundtrip",
				"layers": [{"objects": [
					{ "object_id": "goomba", "position": [1, 2] },
				]}],
			},
		],
	})
	var level: LevelData = LevelData.from_dict(full)
	assert(level != null)
	assert(LevelData.from_dict(level.to_dict()).to_dict() == level.to_dict())


static func _background(converted: Dictionary) -> Dictionary:
	return ((converted.get("areas") as Array).front() as Dictionary)["background"]
