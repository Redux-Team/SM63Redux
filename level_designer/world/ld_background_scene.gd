class_name LDBackgroundScene
extends Node2D


signal camera_synced(center: Vector2, zoom: Vector2)


var background_layer: LDBackgroundLayer

var camera_center: Vector2 = Vector2.ZERO
var camera_zoom: Vector2 = Vector2.ONE
var view_size: Vector2 = Vector2.ZERO


func _process(_delta: float) -> void:
	var camera: Camera2D = find_camera(self)
	if not camera:
		return
	var center: Vector2 = camera.get_screen_center_position()
	if center == camera_center and camera.zoom == camera_zoom:
		return
	camera_center = center
	camera_zoom = camera.zoom
	view_size = camera.get_viewport_rect().size / camera_zoom
	camera_synced.emit(camera_center, camera_zoom)


static func find_camera(from: Node) -> Camera2D:
	var node: Node = from
	while node:
		var viewport: Viewport = node.get_viewport()
		if not viewport:
			return null
		var camera: Camera2D = viewport.get_camera_2d()
		if camera:
			return camera
		node = viewport.get_parent()
	return null
