static func run_test() -> void:
	assert(LevelLayer.scale_from_distance(0.0) == 1.0)
	assert(LevelLayer.scale_from_distance(1.0) == 0.5)
	assert(LevelLayer.scale_from_distance(-0.5) == 2.0)
	assert(LevelLayer.scale_from_distance(100.0) == LevelLayer.scale_from_distance(LevelLayer.DISTANCE_MAX))
	assert(LevelLayer.scale_from_distance(-100.0) == LevelLayer.scale_from_distance(LevelLayer.DISTANCE_MIN))
	
	var data: LayerData = LayerData.create(4)
	data.layer_name = "Hills"
	data.distance = 1.0
	data.modulation = Color(0.5, 0.5, 0.5, 1.0)
	data.silhouette = false
	data.group = &"group"
	var layer: LevelLayer = LevelLayer.build(data, GameObject.Context.EDITOR)
	assert(layer.name == "Layer4")
	assert(layer.get_display_name() == "Hills")
	assert(layer.get_objects_root().scale == Vector2.ONE * 0.5)
	assert(layer.modulate == Color(0.5, 0.5, 0.5, 1.0))
	var round_trip: LayerData = layer.to_data()
	assert(round_trip.uuid == data.uuid)
	assert(round_trip.to_dict() == data.to_dict())
	
	layer.layer_name = ""
	assert(layer.get_display_name() == "Layer 4")
	
	layer.distance = 50.0
	assert(layer.distance == LevelLayer.DISTANCE_MAX)
	layer.distance = -50.0
	assert(layer.distance == LevelLayer.DISTANCE_MIN)
	layer.distance = 1.0
	layer.focus_distance = 1.0
	assert(layer.get_objects_root().scale == Vector2.ONE)
	layer.focus_distance = 0.0
	
	layer.group_distance = 3.0
	assert(layer.get_effective_distance() == 1.0)
	layer.is_decoration = true
	assert(layer.get_effective_distance() == 4.0)
	assert(layer.get_objects_root().scale.is_equal_approx(Vector2.ONE * 0.2))
	assert(layer.get_objects_root().process_mode == Node.PROCESS_MODE_DISABLED)
	layer.is_decoration = false
	assert(layer.get_objects_root().process_mode == Node.PROCESS_MODE_INHERIT)
	layer.group_decoration = true
	assert(layer.get_objects_root().process_mode == Node.PROCESS_MODE_DISABLED)
	assert(layer.get_effective_distance() == 4.0)
	
	layer.inherit({})
	assert(not layer.group_decoration)
	assert(layer.group_distance == 0.0)
	assert(layer.group_modulation == Color.WHITE)
	assert(layer.group_enabled)
	assert(layer.group_visible)
	
	layer.modulation = Color(0.5, 1.0, 1.0, 1.0)
	layer.group_modulation = Color(1.0, 0.5, 1.0, 1.0)
	layer.tint = Color(1.0, 1.0, 0.5, 1.0)
	assert(layer.modulate == Color(0.5, 0.5, 0.5, 1.0))
	layer.modulation_enabled = false
	assert(layer.modulate == Color(1.0, 1.0, 0.5, 1.0))
	layer.enabled = false
	assert(is_equal_approx(layer.modulate.a, LevelLayer.DISABLED_ALPHA))
	assert(not layer.is_effective_enabled())
	layer.enabled = true
	layer.group_enabled = false
	assert(not layer.is_effective_enabled())
	layer.group_enabled = true
	
	layer.editor_visible = false
	assert(not layer.visible)
	layer.editor_visible = true
	layer.group_visible = false
	assert(not layer.visible)
	layer.group_visible = true
	assert(layer.visible)
	
	var first: GameObject = ObjectRegistry.spawn(ObjectData.create(&"yellow_coin"), GameObject.Context.EDITOR)
	var second: GameObject = ObjectRegistry.spawn(ObjectData.create(&"goomba"), GameObject.Context.EDITOR)
	var third: GameObject = ObjectRegistry.spawn(ObjectData.create(&"blue_coin"), GameObject.Context.EDITOR)
	layer.add_object(first)
	layer.add_object(second)
	layer.add_object(third, 0)
	assert(layer.get_objects() == ([third, first, second] as Array[GameObject]))
	assert(layer.remove_object(first) == 1)
	assert(layer.get_objects() == ([third, second] as Array[GameObject]))
	layer.add_object(first, 1)
	assert(layer.get_objects() == ([third, first, second] as Array[GameObject]))
	layer.get_objects_root().add_child(Node2D.new())
	assert(layer.get_objects().size() == 3)
	var captured: LayerData = layer.capture()
	assert(captured.objects.size() == 3)
	assert((captured.objects.front() as ObjectData).id == &"blue_coin")
	assert((captured.objects.front() as ObjectData).uuid == third.uuid)
	layer.free()
	
	var decoration_data: LayerData = LayerData.create(0)
	decoration_data.is_decoration = true
	decoration_data.objects.append(ObjectData.create(&"yellow_coin"))
	decoration_data.objects.append(ObjectData.create(&"missing_object_id"))
	var decoration: LevelLayer = LevelLayer.build(decoration_data, GameObject.Context.GAME)
	assert(decoration.get_objects().size() == 1)
	assert(decoration.get_objects_root().process_mode == Node.PROCESS_MODE_DISABLED)
	decoration.free()
