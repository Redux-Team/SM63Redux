static func run_test() -> void:
	var samples: Array[ObjectData] = [
		_sample(
				&"terrain_grass",
				{
					"outer": PackedVector2Array(
							[Vector2(0, 0), Vector2(96, 0), Vector2(96, 96), Vector2(0, 96)]
					),
					"holes": [
						PackedVector2Array(
								[Vector2(32, 32), Vector2(64, 32), Vector2(64, 64), Vector2(32, 64)]
						),
					],
					"toplines": [Vector3i(0, 1, 1), Vector3i(1, 0, 0)],
				},
		),
		_sample(
				&"terrain_color_solid",
				{
					"outer": PackedVector2Array([Vector2(0, 0), Vector2(64, -32), Vector2(64, 64)]),
					"holes": [],
					"toplines": [],
				},
		),
		_sample(
				&"water",
				{
					"outer": PackedVector2Array(
							[Vector2(-50, -50), Vector2(50, -50), Vector2(50, 50), Vector2(-50, 50)]
					),
					"holes": [],
					"toplines": [],
				},
		),
		_sample(
				&"tall_mushroom",
				{
					"points": PackedVector2Array([Vector2(0, 0), Vector2(8, -40), Vector2(0, -80)]),
				},
		),
		_sample(&"wooden_platform", { "units": 3 }),
		_sample(&"spinning_block", { "size": Vector2(64, 64) }),
		_sample(&"goomba", {}),
	]
	(samples[1] as ObjectData).values[&"color"] = Color.ORANGE
	(samples[1] as ObjectData).values[&"collision_mode"] = 0
	(samples[5] as ObjectData).values[&"b_wait_time"] = 3.5
	(samples[0] as ObjectData).rotation = 0.25
	
	for context: GameObject.Context in [GameObject.Context.EDITOR, GameObject.Context.GAME]:
		for data: ObjectData in samples:
			var object: GameObject = ObjectRegistry.spawn(data, context)
			assert(object != null)
			assert(object.context == context)
			var saved: ObjectData = object.to_data()
			assert(saved.uuid == data.uuid)
			assert(saved.id == data.id)
			assert(saved.position == data.position)
			assert(saved.shape == data.shape)
			if object.has_flag(GameObject.Flag.ROTATABLE):
				assert(is_equal_approx(saved.rotation, data.rotation))
			for key: StringName in data.values:
				assert(saved.values.get(key) == data.values[key])
			for property: ObjectProperty in object.properties:
				assert(saved.values.has(property.key))
			var again: GameObject = ObjectRegistry.spawn(saved, context)
			assert(again.to_data().to_dict() == saved.to_dict())
			again.free()
			object.free()
	
	var area: AreaData = AreaData.create("Shapes")
	(area.layers.front() as LayerData).objects.assign(samples)
	var built: LevelArea = LevelArea.build(area, GameObject.Context.EDITOR)
	var captured: Array[ObjectData] = (built.capture().layers.front() as LayerData).objects
	assert(captured.size() == samples.size())
	for i: int in samples.size():
		assert((captured[i] as ObjectData).shape == (samples[i] as ObjectData).shape)
		assert((captured[i] as ObjectData).uuid == (samples[i] as ObjectData).uuid)
	built.free()


static func _sample(id: StringName, shape: Dictionary) -> ObjectData:
	var data: ObjectData = ObjectData.create(id)
	data.position = Vector2(48, -16)
	data.shape = shape
	return data
