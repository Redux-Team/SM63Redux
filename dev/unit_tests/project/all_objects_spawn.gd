static func run_test() -> void:
	ObjectRegistry.scan()
	var entries: Array[ObjectRegistry.Entry] = ObjectRegistry.get_entries()
	assert(entries.size() > 10)
	
	var ids: Array[StringName] = []
	for entry: ObjectRegistry.Entry in entries:
		assert(not entry.id.is_empty())
		assert(not ids.has(entry.id))
		ids.append(entry.id)
		if entry.browsable and entry.get_icon() == null:
			push_error("Browsable object has no icon: %s" % entry.id)
		
		for context: GameObject.Context in [GameObject.Context.EDITOR, GameObject.Context.GAME]:
			var object: GameObject = ObjectRegistry.spawn(ObjectData.create(entry.id), context)
			if object == null:
				push_error("Object failed to spawn: %s (%s)" % [entry.id, GameObject.Context.find_key(context)])
				continue
			
			assert(object.to_data().id == entry.id)
			object.free()
