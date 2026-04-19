class_name LevelOrbitPlatform
extends LevelObject

@export var platform_nine_patch: NinePatchRect
@export var platform_collision_shape: CollisionShape2D
@export var platform_container: Node2D
@export var preview_container: Node2D
@export var path_drawer: Node2D

var _platforms: Array[AnimatableBody2D] = []
var _pivots: Node2D


func _on_init() -> void:
	preview_container.hide()
	preview_container.queue_free()
	_pivots = Node2D.new()
	platform_container.add_child(_pivots)
	_rebuild_platforms()


func _process(delta: float) -> void:
	var speed: float = get_property(&"platform_speed") if get_property(&"platform_speed") != null else 1.0
	_pivots.rotation += delta * speed


func _rebuild_platforms() -> void:
	for p: AnimatableBody2D in _platforms:
		p.queue_free()
	_platforms.clear()
	for c: Node in _pivots.get_children():
		c.queue_free()
	
	var amount: int = int(get_property(&"platform_amount")) if get_property(&"platform_amount") != null else 3
	var units: int = int(get_property(&"t_size_x")) if get_property(&"t_size_x") != null else 1
	var radius: float = get_property(&"platform_radius") if get_property(&"platform_radius") != null else 64.0
	
	path_drawer.platform_radius = radius
	
	for i: int in amount:
		var body: AnimatableBody2D = _build_platform(units)
		platform_container.add_child(body)
		_platforms.append(body)
		
		var pivot: Node2D = Node2D.new()
		pivot.position = Vector2.RIGHT.rotated((TAU / amount) * i) * radius
		
		var remote: RemoteTransform2D = RemoteTransform2D.new()
		remote.update_rotation = false
		pivot.add_child(remote)
		_pivots.add_child(pivot)
		
		remote.remote_path = remote.get_path_to(body)


func _build_platform(units: int) -> AnimatableBody2D:
	var body: AnimatableBody2D = AnimatableBody2D.new()
	body.sync_to_physics = true
	
	if platform_nine_patch:
		var sprite: NinePatchRect = NinePatchRect.new()
		sprite.texture = platform_nine_patch.texture
		sprite.patch_margin_left = platform_nine_patch.patch_margin_left
		sprite.patch_margin_right = platform_nine_patch.patch_margin_right
		sprite.patch_margin_top = platform_nine_patch.patch_margin_top
		sprite.patch_margin_bottom = platform_nine_patch.patch_margin_bottom
		sprite.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
		var ml: int = platform_nine_patch.patch_margin_left
		var mr: int = platform_nine_patch.patch_margin_right
		var seg_w: int = platform_nine_patch.texture.get_width() - ml - mr
		var total_w: float = float(ml + seg_w * units + mr)
		var h: float = float(platform_nine_patch.texture.get_height())
		sprite.size = Vector2(total_w, h)
		sprite.position = Vector2(-total_w / 2.0, -h / 2.0)
		body.add_child(sprite)
	
	if platform_collision_shape:
		var duped: CollisionShape2D = platform_collision_shape.duplicate() as CollisionShape2D
		var src: RectangleShape2D = platform_collision_shape.shape as RectangleShape2D
		var rect: RectangleShape2D = RectangleShape2D.new()
		if platform_nine_patch and platform_nine_patch.texture and src:
			var ml: int = platform_nine_patch.patch_margin_left
			var mr: int = platform_nine_patch.patch_margin_right
			var seg_w: int = platform_nine_patch.texture.get_width() - ml - mr
			var total_w: float = float(ml + seg_w * units + mr)
			rect.size = Vector2(total_w, src.size.y)
		duped.shape = rect
		duped.position = platform_collision_shape.position
		body.add_child(duped)
	
	return body
