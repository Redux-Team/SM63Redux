@tool
extends LDObjectTelescoping

@export var ghost_root: Node2D
@export var platform_nine_patch: NinePatchRect

@export_group("Placeholders")
@export var speed: float = 1
@export var amount: int = 1
@export var radius: float = 64

var size: int


func _apply_property(key: StringName, value: Variant) -> void:
	if key == "t_size_x":
		size = value
	super(key, value)


func _ready() -> void:
	ghost_root.draw.connect(_draw_platform_sliced_on.bind(ghost_root, Vector2.ZERO, Color(1, 1, 1, 0.5)), CONNECT_REFERENCE_COUNTED)


func _process(delta: float) -> void:
	if is_preview:
		queue_redraw()
	ghost_root.rotate(delta * speed)


func _draw() -> void:
	ghost_root.queue_redraw()


func _draw_platform_sliced_on(target: CanvasItem, pos: Vector2, modulate_color: Color = Color.WHITE) -> void:
	var units: int = size
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
