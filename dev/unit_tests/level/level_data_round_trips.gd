static func run_test() -> void:
	var object: ObjectData = ObjectData.from_dict({})
	assert(not String(object.uuid).is_empty())
	assert(object.id == &"")
	assert(object.position == Vector2.ZERO)
	assert(object.rotation == 0.0)
	assert(object.scale == Vector2.ONE)
	assert(object.values.is_empty())
	assert(object.shape.is_empty())
	
	var block: ObjectData = ObjectData.create(&"spinning_block")
	assert(block.id == &"spinning_block")
	assert(block.uuid != ObjectData.create(&"spinning_block").uuid)
	block.position = Vector2(48.0, -16.0)
	block.rotation = 1.25
	block.scale = Vector2(2.0, 0.5)
	block.values[&"b_wait_time"] = 4.0
	block.shape = { "size": Vector2(64.0, 96.0) }
	var block_dict: Dictionary = block.to_dict()
	assert(ObjectData.from_dict(block_dict).to_dict() == block_dict)
	
	var copy: ObjectData = block.duplicate_with_new_uuid()
	assert(copy.uuid != block.uuid)
	assert(copy.id == block.id)
	assert(copy.position == block.position)
	assert(copy.values == block.values)
	copy.values[&"b_wait_time"] = 1.0
	copy.shape["size"] = Vector2.ONE
	assert(block.values[&"b_wait_time"] == 4.0)
	assert(block.shape["size"] == Vector2(64.0, 96.0))
	
	var layer: LayerData = LayerData.from_dict({})
	assert(layer.index == 0)
	assert(layer.layer_name.is_empty())
	assert(layer.distance == 0.0)
	assert(layer.modulation == Color.WHITE)
	assert(not layer.is_decoration)
	assert(layer.silhouette)
	assert(layer.enabled)
	assert(layer.editor_visible)
	assert(layer.group == &"")
	assert(layer.objects.is_empty())
	
	var custom: LayerData = LayerData.create(3)
	assert(custom.index == 3)
	custom.layer_name = "Foreground"
	custom.distance = -0.5
	custom.modulation = Color(0.5, 0.25, 1.0, 0.75)
	custom.is_decoration = true
	custom.silhouette = false
	custom.enabled = false
	custom.editor_visible = false
	custom.group = &"group_uuid"
	custom.objects.append(block)
	var layer_dict: Dictionary = custom.to_dict()
	assert(layer_dict.get("name") == "Foreground")
	assert(layer_dict.get("visible") == false)
	assert(LayerData.from_dict(layer_dict).to_dict() == layer_dict)
	
	var area: AreaData = AreaData.from_dict({})
	assert(area.area_name.is_empty())
	assert(area.camera_zoom == 1.0)
	assert(area.layers.is_empty())
	assert(area.layer_groups.is_empty())
	
	var created: AreaData = AreaData.create("Cave")
	assert(created.area_name == "Cave")
	assert(created.layers.size() == 1)
	assert((created.layers.front() as LayerData).index == 0)
	created.camera_position = Vector2(100.0, 200.0)
	created.camera_zoom = 2.0
	created.active_layer = 1
	created.background = { "preset": "snowy_peaks" }
	created.music = { "subtracks": [1, 2] }
	created.layer_groups.append({ "uuid": &"group_uuid", "distance": 1.5 })
	created.layers.append(custom)
	var area_dict: Dictionary = created.to_dict()
	assert(AreaData.from_dict(area_dict).to_dict() == area_dict)
	
	var level: LevelData = LevelData.create()
	assert(level.version == LevelData.VERSION)
	assert(level.areas.size() == 1)
	assert((level.areas.front() as AreaData).area_name == "Area 1")
	level.areas.append(created)
	level.level_name = "Test Level"
	level.editor = { "active_area": 1 }
	level.extras = { "v1": { "tags": ["a"] } }
	assert(level.find_area(created.uuid) == created)
	assert(level.find_area(&"missing") == null)
	var level_dict: Dictionary = level.to_dict()
	var restored: LevelData = LevelData.from_dict(level_dict)
	assert(restored.to_dict() == level_dict)
	assert(restored.find_area(created.uuid).area_name == "Cave")
	
	UnitTester.expect_error("unsupported level version 0")
	assert(LevelData.from_dict({}) == null)
	UnitTester.expect_error("unsupported level version 3")
	assert(LevelData.from_dict({ "version": 3 }) == null)
