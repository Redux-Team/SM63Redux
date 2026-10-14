@tool
class_name GameObject
extends Node2D

signal value_changed(key: StringName, value: Variant)

enum Context {
	EDITOR,
	GAME,
}

enum Placement {
	BEHIND_ALL,
	BEHIND_PLAYER,
	FRONT_PLAYER,
	FRONT_ALL,
}

enum Flag {
	SELECTABLE = 1,
	DELETABLE = 2,
	LAYERABLE = 4,
	COPYABLE = 8,
	MOVABLE = 16,
	ROTATABLE = 32,
	SCALABLE = 64,
}

@export_group("Definition")
@export var id: StringName
@export var display_name: String
@export var icon: Texture2D
@export var icon_tint: StringName
@export var category: StringName
@export var group: StringName
@export var biome: StringName
@export var order: int = 0
@export var placement: Placement = Placement.BEHIND_PLAYER
@export var browsable: bool = true
@export var unique: bool = false
@export var cullable: bool = true
@export_flags("Selectable", "Deletable", "Layerable", "Copyable", "Movable", "Rotatable", "Scalable") var flags: int = 31
@export var properties: Array[ObjectProperty]
@export_group("Nodes")
@export var game_root: Node
@export var editor_root: Node
@export var shape: ObjectShape
@export var occluders: Array[CanvasItem]
@export var bounds_override: Rect2

var uuid: StringName
var context: Context = Context.GAME
var _values: Dictionary[StringName, Variant] = {}
var _bounds: Rect2
var _bounds_valid: bool = false


static func of(node: Node) -> GameObject:
	var current: Node = node
	while current and not current is GameObject:
		current = current.get_parent()
	
	return current as GameObject


static func spawn(scene: PackedScene, spawn_context: Context, data: ObjectData = null) -> GameObject:
	var object: GameObject = scene.instantiate() as GameObject
	if object == null:
		push_error("GameObject: '%s' does not have a GameObject root." % scene.resource_path)
		return null
	
	object.build(spawn_context)
	object.apply_data(data if data else ObjectData.create(object.id))
	return object


func build(spawn_context: Context) -> void:
	assert(not is_inside_tree(), "GameObject: build() must run before entering the tree.")
	context = spawn_context
	if context == Context.EDITOR:
		_capture_snapshots(editor_root)
		_discard(game_root)
		game_root = null
	else:
		_discard(editor_root)
		editor_root = null
	
	occluders = occluders.filter(is_instance_valid)


func apply_data(data: ObjectData) -> void:
	uuid = data.uuid
	position = data.position
	if has_flag(Flag.ROTATABLE):
		rotation = data.rotation
	if has_flag(Flag.SCALABLE):
		scale = data.scale
	
	for property: ObjectProperty in properties:
		set_value(property.key, data.values.get(property.key))
	
	if shape:
		shape.from_data(data.shape)
	
	invalidate_bounds()


func to_data() -> ObjectData:
	var data: ObjectData = ObjectData.new()
	data.uuid = uuid
	data.id = id
	data.position = position
	data.rotation = rotation
	data.scale = scale
	data.values = _values.duplicate()
	data.shape = shape.to_data() if shape else {}
	return data


func get_value(key: StringName) -> Variant:
	return _values.get(key)


func set_value(key: StringName, value: Variant) -> void:
	var property: ObjectProperty = get_object_property(key)
	if property == null:
		push_warning("GameObject (%s): no property named '%s'." % [id, key])
		return
	
	var resolved: Variant = property.coerce(value)
	_values.set(key, resolved)
	property.apply(self, resolved)
	invalidate_bounds()
	value_changed.emit(key, resolved)


func get_values() -> Dictionary[StringName, Variant]:
	return _values.duplicate()


func get_object_property(key: StringName) -> ObjectProperty:
	for property: ObjectProperty in properties:
		if property.key == key:
			return property
	
	return null


func has_flag(flag: Flag) -> bool:
	return flags & flag != 0


func get_icon() -> Texture2D:
	if icon:
		return icon
	
	for sprite: Sprite2D in _find_sprites(self):
		if sprite.texture:
			return sprite.texture
	
	return null


func get_occluders() -> Array[CanvasItem]:
	var found: Array[CanvasItem] = []
	if is_solid():
		return found
	
	if occluders.is_empty():
		found.assign(_find_visuals(self))
	else:
		found.assign(occluders)
	
	return found


func is_solid() -> bool:
	if game_root == null or not game_root.can_process():
		return false
	
	return game_root is CollisionObject2D or not game_root.find_children("*", "CollisionObject2D", true, false).is_empty()


func get_local_bounds() -> Rect2:
	if bounds_override.has_area():
		return bounds_override
	
	if shape:
		return shape.get_local_bounds()
	
	if not _bounds_valid:
		_bounds = _compute_sprite_bounds()
		_bounds_valid = true
	
	return _bounds


func contains_point(world_point: Vector2) -> bool:
	var local_point: Vector2 = get_global_transform().affine_inverse() * world_point
	if shape and not bounds_override.has_area():
		return shape.contains_point(local_point)
	
	return get_local_bounds().has_point(local_point)


func get_outlines() -> Array[PackedVector2Array]:
	if shape and not bounds_override.has_area():
		return shape.get_outlines()
	
	var rect: Rect2 = get_local_bounds()
	return [PackedVector2Array([rect.position, Vector2(rect.end.x, rect.position.y), rect.end, Vector2(rect.position.x, rect.end.y)])]


func get_global_bounds() -> Rect2:
	return get_global_transform() * get_local_bounds()


func invalidate_bounds() -> void:
	_bounds_valid = false


func _compute_sprite_bounds() -> Rect2:
	var bounds: Rect2 = Rect2()
	var first: bool = true
	for sprite: Sprite2D in _find_sprites(self):
		if not sprite.texture:
			continue
		
		var rect: Rect2 = relative_transform(self, sprite) * sprite.get_rect()
		bounds = rect if first else bounds.merge(rect)
		first = false
	
	return bounds if not first else Rect2(-8.0, -8.0, 16.0, 16.0)


static func relative_transform(ancestor: Node, node: Node) -> Transform2D:
	var result: Transform2D = Transform2D.IDENTITY
	var current: Node = node
	while current and current != ancestor:
		if current is Node2D:
			result = (current as Node2D).transform * result
		current = current.get_parent()
	
	return result


static func _find_visuals(root: Node) -> Array[CanvasItem]:
	var visuals: Array[CanvasItem] = []
	for child: Node in root.get_children():
		var item: CanvasItem = child as CanvasItem
		if item and not item.visible:
			continue
		if item is Sprite2D or item is AnimatedSprite2D or item is Line2D or item is NinePatchRect or item is TextureRect:
			visuals.append(item)
		visuals.append_array(_find_visuals(child))
	
	return visuals


static func _find_sprites(root: Node) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	for child: Node in root.get_children():
		if child is Sprite2D and (child as Sprite2D).visible:
			sprites.append(child)
		if child is CanvasItem and not (child as CanvasItem).visible:
			continue
		sprites.append_array(_find_sprites(child))
	
	return sprites


func _capture_snapshots(root: Node) -> void:
	if root == null:
		return
	
	if root is SnapshotView:
		(root as SnapshotView).capture(self)
	
	for child: Node in root.get_children():
		_capture_snapshots(child)


func _discard(node: Node) -> void:
	if node:
		node.free()
