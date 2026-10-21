class_name TestStage
extends RefCounted

const LEVEL: PackedScene = preload("res://game/level/level.tscn")
const GROUND: StringName = &"terrain_color_solid"
const FLOOR_Y: float = 40.0

var data: LevelData = LevelData.create()
var level: Level
var player: Player
var _held: Array[StringName] = []


static func create(with_player: bool = true, with_floor: bool = true, player_position: Vector2 = Vector2.ZERO) -> TestStage:
	var stage: TestStage = TestStage.new()
	if with_player:
		stage.add(&"player_mario", player_position)
	if with_floor:
		stage.add_polygon(GROUND, Rect2(-2000.0, FLOOR_Y, 4000.0, 400.0))
	return stage


func get_area() -> AreaData:
	return data.areas.front()


func get_layer(index: int = 0) -> LayerData:
	return get_area().layers.get(index)


func add_layer(decoration: bool = false) -> LayerData:
	var layer: LayerData = LayerData.create(get_area().layers.size())
	layer.is_decoration = decoration
	get_area().layers.append(layer)
	return layer


func add(id: StringName, position: Vector2 = Vector2.ZERO, layer: LayerData = get_layer()) -> ObjectData:
	var object: ObjectData = ObjectData.create(id)
	object.position = position
	layer.objects.append(object)
	return object


func add_polygon(id: StringName, rect: Rect2, layer: LayerData = get_layer()) -> ObjectData:
	return add_shape(id, PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)]), layer)


func add_shape(id: StringName, outer: PackedVector2Array, layer: LayerData = get_layer()) -> ObjectData:
	var object: ObjectData = add(id, Vector2.ZERO, layer)
	object.shape = {"outer": outer, "holes": [], "toplines": []}
	return object


func start(settle_frames: int = 30) -> void:
	TestStage.reset()
	level = LEVEL.instantiate()
	_get_tree().root.add_child(level)
	level.prepare(data)
	await level.attach(0)
	player = level.get_player()
	await step(settle_frames)


func step(frames: int = 1) -> void:
	for i: int in frames:
		await _get_tree().physics_frame


func step_until(condition: Callable, max_frames: int = 600) -> bool:
	for i: int in max_frames:
		if condition.call():
			return true
		await step()
	return condition.call()


func step_until_state(state: StringName, max_frames: int = 600) -> bool:
	return await step_until(func() -> bool: return get_state() == state, max_frames)


func trace_states(frames: int) -> Array[StringName]:
	var trace: Array[StringName] = [get_state()]
	for i: int in frames:
		await step()
		if trace.back() != get_state():
			trace.append(get_state())
	
	return trace


func get_state() -> StringName:
	return player.machine.get_state_name()


func give_cap(cap: StringName) -> void:
	player.caps.start(cap, true)


func equip_nozzle(nozzle: PlayerFludd.Nozzle) -> void:
	player.fludd.held_nozzles.set(nozzle, true)
	player.fludd.equipped_nozzle = nozzle


func hold(action: StringName) -> void:
	Input.action_press(action)
	if not _held.has(action):
		_held.append(action)


func release(action: StringName) -> void:
	Input.action_release(action)
	_held.erase(action)


func tap(action: StringName, frames: int = 1) -> void:
	hold(action)
	await step(frames)
	release(action)


func finish() -> void:
	for action: StringName in _held.duplicate():
		release(action)
	
	if is_instance_valid(level):
		level.free()
	
	await step()


static func reset() -> void:
	for action: StringName in InputMap.get_actions():
		Input.action_release(action)
	
	for leftover: Node in (Engine.get_main_loop() as SceneTree).get_nodes_in_group(&"level"):
		leftover.free()


func _get_tree() -> SceneTree:
	return Engine.get_main_loop()
