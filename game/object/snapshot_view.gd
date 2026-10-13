@tool
class_name SnapshotView
extends Node2D

@export var source: Node
@export var prefer_icon: bool = true


func capture(object: GameObject) -> void:
	if prefer_icon and object.icon:
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = object.icon
		add_child(sprite)
		return
	
	if source == null:
		return
	
	var origin: Node = source.get_parent()
	var inverse: Transform2D = GameObject.relative_transform(origin, self).affine_inverse()
	for sprite: Sprite2D in _collect(source):
		var copy: Sprite2D = Sprite2D.new()
		copy.texture = sprite.texture
		copy.centered = sprite.centered
		copy.offset = sprite.offset
		copy.flip_h = sprite.flip_h
		copy.flip_v = sprite.flip_v
		copy.hframes = sprite.hframes
		copy.vframes = sprite.vframes
		copy.frame = sprite.frame
		copy.region_enabled = sprite.region_enabled
		copy.region_rect = sprite.region_rect
		copy.modulate = sprite.modulate
		copy.self_modulate = sprite.self_modulate
		copy.material = sprite.material
		copy.z_index = sprite.z_index
		copy.transform = inverse * GameObject.relative_transform(origin, sprite)
		add_child(copy)


func _collect(node: Node) -> Array[Sprite2D]:
	var sprites: Array[Sprite2D] = []
	if node is CanvasItem and not (node as CanvasItem).visible:
		return sprites
	
	if node is Sprite2D and (node as Sprite2D).texture:
		sprites.append(node)
	
	for child: Node in node.get_children():
		sprites.append_array(_collect(child))
	
	return sprites
