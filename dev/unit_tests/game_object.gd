@tool
static func run_test() -> void:
	ObjectRegistry.scan()
	
	var tree_entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(&"medium_tree")
	assert(tree_entry != null)
	assert(tree_entry.display_name == "Medium Tree")
	assert(tree_entry.category == &"Decoration")
	assert(tree_entry.browsable)
	assert(tree_entry.get_icon() != null)
	
	var player_entry: ObjectRegistry.Entry = ObjectRegistry.get_entry(&"player_mario")
	assert(player_entry.unique)
	assert(not player_entry.has_flag(GameObject.Flag.DELETABLE))
	assert(player_entry.get_shape_kind() == ObjectShape.Kind.NONE)
	assert(ObjectRegistry.get_entry(&"missing_object") == null)
	
	var editor_player: GameObject = ObjectRegistry.spawn(ObjectData.create(&"player_mario"), GameObject.Context.EDITOR)
	assert(editor_player.game_root == null)
	assert(not editor_player.has_node(^"Game"))
	assert(editor_player.editor_root.get_child_count() > 0)
	assert(editor_player.get_local_bounds().has_area())
	editor_player.free()
	
	var game_player: GameObject = ObjectRegistry.spawn(ObjectData.create(&"player_mario"), GameObject.Context.GAME)
	assert(game_player.editor_root == null)
	assert(not game_player.has_node(^"Editor"))
	assert(game_player.game_root is Player)
	game_player.free()
	
	var data: ObjectData = ObjectData.create(&"debug_block")
	data.position = Vector2(10.5, -20.25)
	data.scale = Vector2(2.0, 1.0)
	var block: GameObject = ObjectRegistry.spawn(data, GameObject.Context.GAME)
	assert(block.position == data.position)
	assert(block.scale == data.scale)
	assert(block.uuid == data.uuid)
	assert(block.occluders.size() == 1)
	assert(block.to_data().to_dict() == data.to_dict())
	
	var tint: ObjectProperty = ObjectProperty.new()
	tint.key = &"tint"
	tint.type = ObjectProperty.Type.COLOR
	tint.default_value = Color.WHITE
	tint.targets = [^"Fill", ^"Game", ^"Missing"]
	tint.member = &"modulate"
	block.properties.append(tint)
	block.set_value(&"tint", Color.RED)
	assert(block.get_value(&"tint") == Color.RED)
	assert((block.get_node(^"Fill") as CanvasItem).modulate == Color.RED)
	assert((block.get_node(^"Game") as CanvasItem).modulate == Color.RED)
	block.free()
	
	var amount: ObjectProperty = ObjectProperty.new()
	amount.type = ObjectProperty.Type.INT
	amount.default_value = 3
	amount.min_value = 1.0
	amount.max_value = 8.0
	assert(amount.coerce(null) == 3)
	assert(amount.coerce(20.7) == 8)
	assert(typeof(amount.coerce(2.0)) == TYPE_INT)
	
	var angle: ObjectProperty = ObjectProperty.new()
	angle.min_value = 0.0
	angle.max_value = 360.0
	angle.wrap_value = true
	assert(is_equal_approx(angle.coerce(370.0), 10.0))
