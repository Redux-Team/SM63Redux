class_name MovingPlatform
extends Prop

@export var texture: Texture2D
@export var margin_left: int = 10
@export var margin_right: int = 10
@export var collision_offset: Vector2 = Vector2(0, -5)
@export var collision_height: float = 4.0
@export var one_way_margin: float = 2.0

var _pivot: Node2D
var _holder: Node2D


static func build_visual(
		platform_texture: Texture2D,
		left: int,
		right: int,
		units: int,
) -> NinePatchRect:
	var segment: int = platform_texture.get_width() - left - right
	var patch: NinePatchRect = NinePatchRect.new()
	patch.texture = platform_texture
	patch.patch_margin_left = left
	patch.patch_margin_right = right
	patch.axis_stretch_horizontal = NinePatchRect.AXIS_STRETCH_MODE_TILE
	patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	patch.size = Vector2(left + right + segment * maxi(units, 0), platform_texture.get_height())
	patch.position = -patch.size * 0.5
	return patch


static func get_offsets(amount: int, radius: float) -> PackedVector2Array:
	var offsets: PackedVector2Array = PackedVector2Array()
	for i: int in amount:
		offsets.append(Vector2.RIGHT.rotated(TAU / amount * i) * radius)
	
	return offsets


func _physics_process(delta: float) -> void:
	_pivot.rotation += delta * float(get_property(&"platform_period", 1.0))
	_holder.global_rotation = 0.0


func _on_init() -> void:
	_pivot = Node2D.new()
	add_child(_pivot)
	_holder = Node2D.new()
	add_child(_holder)
	var units: int = get_property(&"platform_width", 1)
	for offset: Vector2 in get_offsets(
			get_property(&"platform_amount", 1),
			get_property(&"platform_radius", 64.0),
	):
		var platform: AnimatableBody2D = _build_platform(units)
		_holder.add_child(platform)
		var remote: RemoteTransform2D = RemoteTransform2D.new()
		remote.update_rotation = false
		remote.update_scale = false
		remote.position = offset
		_pivot.add_child(remote)
		remote.remote_path = remote.get_path_to(platform)
		platform.global_position = remote.global_position


func _build_platform(units: int) -> AnimatableBody2D:
	var platform: AnimatableBody2D = AnimatableBody2D.new()
	platform.collision_layer = 2
	platform.collision_mask = 0
	platform.sync_to_physics = true
	var visual: NinePatchRect = build_visual(texture, margin_left, margin_right, units)
	platform.add_child(visual)
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = Vector2(visual.size.x, collision_height)
	var collision: CollisionShape2D = CollisionShape2D.new()
	collision.shape = rectangle
	collision.position = collision_offset
	collision.one_way_collision = true
	collision.one_way_collision_margin = one_way_margin
	platform.add_child(collision)
	return platform
