static func run_test() -> void:
	ObjectRegistry.scan()
	assert(ObjectRegistry.is_scanned())
	var entries: Array[ObjectRegistry.Entry] = ObjectRegistry.get_entries()
	assert(entries.size() > 100)
	
	var ids: Dictionary[StringName, bool] = {}
	var unique: Array[StringName] = []
	for entry: ObjectRegistry.Entry in entries:
		assert(not String(entry.id).is_empty())
		assert(not ids.has(entry.id))
		ids[entry.id] = true
		assert(entry.path.begins_with(ObjectRegistry.ROOT))
		assert(entry.path.get_file().get_basename() == String(entry.id))
		assert(not entry.path.get_file().begins_with("_"))
		assert(entry.scene != null)
		assert(ObjectRegistry.get_entry(entry.id) == entry)
		assert(ObjectRegistry.get_scene(entry.id) == entry.scene)
		assert(not entry.display_name.is_empty())
		assert(not String(entry.category).is_empty())
		assert(not String(entry.group).is_empty())
		if entry.unique:
			unique.append(entry.id)
	assert(unique == ([&"player_mario"] as Array[StringName]))
	
	assert(ObjectRegistry.get_entry(&"terrain_grass").get_shape_kind() == ObjectShape.Kind.POLYGON)
	assert(ObjectRegistry.get_entry(&"water").get_shape_kind() == ObjectShape.Kind.POLYGON)
	assert(ObjectRegistry.get_entry(&"tall_mushroom").get_shape_kind() == ObjectShape.Kind.PATH)
	assert(
			ObjectRegistry.get_entry(&"wooden_platform").get_shape_kind()
			== ObjectShape.Kind.TELESCOPING
	)
	assert(ObjectRegistry.get_entry(&"spinning_block").get_shape_kind() == ObjectShape.Kind.BLOCK)
	assert(ObjectRegistry.get_entry(&"goomba").get_shape_kind() == ObjectShape.Kind.NONE)
	
	var player: ObjectRegistry.Entry = ObjectRegistry.get_entry(&"player_mario")
	assert(player.has_flag(GameObject.Flag.SELECTABLE))
	assert(player.has_flag(GameObject.Flag.MOVABLE))
	assert(not player.has_flag(GameObject.Flag.COPYABLE))
	assert(not player.has_flag(GameObject.Flag.ROTATABLE))
	assert(ObjectRegistry.get_entry(&"yellow_coin").has_flag(GameObject.Flag.SCALABLE))
	
	var tinted: ObjectRegistry.Entry = ObjectRegistry.get_entry(&"terrain_color_solid")
	var default_color: Color = tinted.get_icon_color()
	assert(default_color != Color.WHITE)
	assert(tinted.get_icon_color({ &"color": Color.RED }) == Color.RED)
	var red_icon: Texture2D = tinted.get_icon({ &"color": Color.RED })
	assert(red_icon != null)
	assert(tinted.get_icon({ &"color": Color.RED }) == red_icon)
	assert(tinted.get_icon({ &"color": Color.BLUE }) != red_icon)
	assert(tinted.get_icon({ &"color": Color.WHITE }) == tinted.icon)
	assert(
			ObjectRegistry.get_entry(&"goomba").get_icon_color({ &"color": Color.RED })
			== Color.WHITE
	)
	
	assert(ObjectRegistry.get_entry(&"missing_object_id") == null)
	assert(ObjectRegistry.get_scene(&"missing_object_id") == null)
	assert(
			ObjectRegistry.spawn(ObjectData.create(&"missing_object_id"), GameObject.Context.GAME)
			== null
	)
	
	ObjectRegistry.scan(true)
	assert(ObjectRegistry.get_entries().size() == entries.size())
	assert(ObjectRegistry.get_entry(&"goomba") != null)
