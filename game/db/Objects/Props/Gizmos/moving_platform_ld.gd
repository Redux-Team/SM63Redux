@tool
extends LDObjectSprite
enum Mode {
	ORBIT
}
@export var mode: Mode = Mode.ORBIT
@export var center_texture: Texture2D
@export var platform_nine_patch: NinePatchRect
@export var path_drawer: Node2D
@export var ghost_container: Node2D
@export var ghost_root: Node2D
@export_group("Placeholders")
@export var width: int = 1
@export var speed: float = 1
@export var amount: int = 1
@export var radius: float = 64


func _process(_delta: float) -> void:
	if is_preview:
		if ghost_root:
			ghost_root.visible = false
		return
	queue_redraw()
	if ghost_container:
		var platform_period: float = get_property(&"platform_period") if has_property(&"platform_period") else speed
		ghost_container.rotation += platform_period * get_process_delta_time()
	if ghost_root:
		ghost_root.visible = true


func _draw_platform_sliced_on(target: CanvasItem, pos: Vector2, units: int, modulate_color: Color = Color.WHITE) -> void:
	if not platform_nine_patch or not platform_nine_patch.texture:
		var fallback_w: float = float(units) * 16.0
		target.draw_rect(Rect2(pos - Vector2(fallback_w / 2.0, 4.0), Vector2(fallback_w, 8.0)), modulate_color)
		return
	var tex: Texture2D = platform_nine_patch.texture
	var ml: int = platform_nine_patch.patch_margin_left
	var mr: int = platform_nine_patch.patch_margin_right
	var h: float = float(tex.get_height())
	var half_h: float = h / 2.0
	var seg_w: int = tex.get_width() - ml - mr
	var total_w: float = float(ml + seg_w * units + mr)
	var half_w: float = total_w / 2.0
	var src_l: Rect2 = Rect2(0, 0, ml, h)
	var src_mid: Rect2 = Rect2(ml, 0, seg_w, h)
	var src_r: Rect2 = Rect2(tex.get_width() - mr, 0, mr, h)
	target.draw_texture_rect_region(tex, Rect2(pos + Vector2(-half_w, -half_h), Vector2(ml, h)), src_l, modulate_color)
	for s: int in units:
		var x: float = -half_w + ml + seg_w * s
		target.draw_texture_rect_region(tex, Rect2(pos + Vector2(x, -half_h), Vector2(seg_w, h)), src_mid, modulate_color)
	target.draw_texture_rect_region(tex, Rect2(pos + Vector2(half_w - mr, -half_h), Vector2(mr, h)), src_r, modulate_color)


func _sync_ghost_platforms(platform_amount: int, platform_width: int, platform_radius: float) -> void:
	var anchor_count: int = ghost_container.get_child_count()
	var ghost_count: int = ghost_root.get_child_count()
	for i: int in platform_amount:
		var angle: float = (TAU / platform_amount) * i
		var anchor: Node2D
		if i < anchor_count:
			anchor = ghost_container.get_child(i) as Node2D
		else:
			anchor = Node2D.new()
			ghost_container.add_child(anchor)
		anchor.position = Vector2(cos(angle), sin(angle)) * platform_radius
		var ghost: Node2D
		if i < ghost_count:
			ghost = ghost_root.get_child(i) as Node2D
		else:
			ghost = Node2D.new()
			ghost_root.add_child(ghost)
		if ghost.has_meta(&"draw_callable"):
			ghost.draw.disconnect(ghost.get_meta(&"draw_callable"))
		var callable: Callable = func() -> void: _draw_platform_sliced_on(ghost, Vector2.ZERO, platform_width)
		ghost.set_meta(&"draw_callable", callable)
		ghost.draw.connect(callable)
		ghost.queue_redraw()
		if anchor.get_child_count() == 0:
			var rt: RemoteTransform2D = RemoteTransform2D.new()
			rt.update_rotation = false
			rt.update_scale = false
			anchor.add_child(rt)
		var remote: RemoteTransform2D = anchor.get_child(0) as RemoteTransform2D
		remote.remote_path = ghost.get_path()
	for i: int in range(platform_amount, anchor_count):
		ghost_container.get_child(i).queue_free()
	for i: int in range(platform_amount, ghost_count):
		ghost_root.get_child(i).queue_free()


func _draw() -> void:
	if mode == Mode.ORBIT:
		var platform_radius: float = get_property(&"platform_radius") if has_property(&"platform_radius") else radius
		var platform_amount: int = int(get_property(&"platform_amount")) if has_property(&"platform_amount") else amount
		var platform_width: float = get_property(&"t_size_x") if has_property(&"t_size_x") else width
		var start_angle: float = deg_to_rad(get_property(&"platform_start_angle") if has_property(&"platform_start_angle") else 0.0)
		if path_drawer:
			path_drawer.platform_radius = platform_radius
			path_drawer.queue_redraw()
		if center_texture:
			draw_texture(center_texture, Vector2.ZERO - center_texture.get_size() / 2.0)
		for i: int in platform_amount:
			var base_angle: float = (TAU / platform_amount) * i + start_angle
			var rest_pos: Vector2 = Vector2(cos(base_angle), sin(base_angle)) * platform_radius
			_draw_platform_sliced_on(self, rest_pos, int(platform_width))
		if not is_preview and ghost_container and ghost_root:
			ghost_root.modulate = Color(1.0, 1.0, 1.0, 0.3)
			_sync_ghost_platforms(platform_amount, int(platform_width), int(platform_radius))
