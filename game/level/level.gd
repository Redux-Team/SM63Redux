class_name Level
extends Node2D

signal loaded

@export var world: Node2D
@export var culler: LevelCuller
@export var camera: Camera2D
@export var hud: PlayerHUD
@export var silhouette_source: SilhouetteSource
@export var silhouette_material: Material

var _area: LevelArea
var _player: Player


func load_data(data: LevelData, area_uuid: StringName = &"") -> void:
	var area_data: AreaData = data.find_area(area_uuid)
	if area_data == null:
		area_data = data.areas.front()
	
	_area = LevelArea.build(area_data, GameObject.Context.GAME)
	world.add_child(_area)
	
	for object: GameObject in _area.get_all_objects():
		_track(object)
		if object.game_root is Player:
			_player = object.game_root
	
	if _player:
		_bind_player()
	
	loaded.emit()


func get_area() -> LevelArea:
	return _area


func get_player() -> Player:
	return _player


func _track(object: GameObject) -> void:
	var entity: Entity = object.game_root as Entity
	if entity and not entity.cull_when_offscreen:
		return
	
	if object.game_root is Node2D:
		culler.track(object.game_root)


func _bind_player() -> void:
	camera.reparent(_player, false)
	camera.position = Vector2.ZERO
	camera.reset_smoothing()
	hud.bind(_player)
	silhouette_source.anchor = _player
	silhouette_source.targets = _player.silhouette_targets
	_attach_silhouettes()


func _attach_silhouettes() -> void:
	var in_front: bool = false
	for object: GameObject in _area.get_all_objects():
		if in_front:
			_attach_silhouette(object)
		in_front = in_front or object == _player.object


func _attach_silhouette(object: GameObject) -> void:
	for occluder: CanvasItem in object.get_occluders():
		occluder.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		var view: SilhouetteView = SilhouetteView.new()
		view.source = silhouette_source
		view.material = silhouette_material
		occluder.add_child(view)
