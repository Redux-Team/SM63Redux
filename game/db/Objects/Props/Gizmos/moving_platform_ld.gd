@tool
extends LDObjectSprite

enum Mode {
	ORBIT
}

@export var mode: Mode = Mode.ORBIT
@export var center_texture: Texture2D
@export var platform_nine_patch: NinePatchRect
@export var path_drawer: Node2D

@export_group("Placeholders")
@export var width: int = 1
@export var speed: float = 1
@export var amount: int = 1
@export var radius: float = 64


func _process(_delta: float) -> void:
	if not is_preview:
		queue_redraw()


func _draw_platform_sliced(pos: Vector2, units: int) -> void:
	if not platform_nine_patch or not platform_nine_patch.texture:
		var fallback_w: float = float(units) * 16.0
		draw_rect(Rect2(pos - Vector2(fallback_w / 2.0, 4.0), Vector2(fallback_w, 8.0)), Color.WHITE)
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
	draw_texture_rect_region(tex, Rect2(pos + Vector2(-half_w, -half_h), Vector2(ml, h)), src_l)
	for s: int in units:
		var x: float = -half_w + ml + seg_w * s
		draw_texture_rect_region(tex, Rect2(pos + Vector2(x, -half_h), Vector2(seg_w, h)), src_mid)
	draw_texture_rect_region(tex, Rect2(pos + Vector2(half_w - mr, -half_h), Vector2(mr, h)), src_r)


func _draw() -> void:
	if mode == Mode.ORBIT:
		var platform_radius: float = get_property(&"platform_radius") if has_property(&"platform_radius") != null else radius
		var platform_amount: int = int(get_property(&"platform_amount")) if has_property(&"platform_amount") != null else amount
		var platform_speed: float = get_property(&"platform_speed") if has_property(&"platform_speed") != null else speed
		var platform_width: float = get_property(&"t_size_x") if has_property(&"t_size_x") != null else width
		var t: float = Time.get_ticks_msec() / 1000.0 * platform_speed
		
		if path_drawer:
			path_drawer.platform_radius = platform_radius
			path_drawer.queue_redraw()
		
		if center_texture:
			draw_texture(center_texture, Vector2.ZERO - center_texture.get_size() / 2.0)
		for i: int in platform_amount:
			var angle: float = (TAU / platform_amount) * i + t
			var pos: Vector2 = Vector2(cos(angle), sin(angle)) * platform_radius
			_draw_platform_sliced(pos, int(platform_width))
