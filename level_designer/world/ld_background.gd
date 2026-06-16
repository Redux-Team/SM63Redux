class_name LDBackground
extends Resource

## A level's background: a screen-fixed backdrop (solid color or vertical gradient) plus a stack
## of parallax layers. Used both as a saved preset (see db/Backgrounds and LDBackgroundDB) and as
## the live working copy in the editor. build_into() renders the same node structure for the level
## designer preview and the runtime (mirroring game/backgrounds/hills.tscn).

enum Backdrop { SOLID, GRADIENT }

## Grayscale-tint shader applied to a layer whose `custom_color` is enabled.
const TINT_SHADER: Shader = preload("res://core/shader/background_tint.gdshader")


## Display name when this resource is a preset (empty for the working copy / custom backgrounds).
@export var preset_name: String = ""

@export var backdrop_type: int = Backdrop.GRADIENT
@export var solid_color: Color = Color(0.45, 0.6, 0.9)
@export var gradient_top: Color = Color(0.57, 0.74, 1.0)
@export var gradient_bottom: Color = Color(0.30, 0.46, 0.78)
@export var layers: Array[LDBackgroundLayer] = []


func serialize() -> Dictionary:
	var layer_data: Array = []
	for layer: LDBackgroundLayer in layers:
		layer_data.append(layer.serialize())
	return {
		"backdrop_type": backdrop_type,
		"solid_color": Packer.color_to_array(solid_color),
		"gradient_top": Packer.color_to_array(gradient_top),
		"gradient_bottom": Packer.color_to_array(gradient_bottom),
		"layers": layer_data,
	}


static func deserialize(data: Dictionary) -> LDBackground:
	var bg: LDBackground = LDBackground.new()
	bg.backdrop_type = int(data.get("backdrop_type", Backdrop.GRADIENT))
	if data.has("solid_color"):
		bg.solid_color = Packer.array_to_color(data.get("solid_color"))
	if data.has("gradient_top"):
		bg.gradient_top = Packer.array_to_color(data.get("gradient_top"))
	if data.has("gradient_bottom"):
		bg.gradient_bottom = Packer.array_to_color(data.get("gradient_bottom"))
	bg.layers.clear()
	for raw: Variant in data.get("layers", []):
		if raw is Dictionary:
			bg.layers.append(LDBackgroundLayer.deserialize(raw))
	return bg


## (Re)builds the background nodes into `root`, clearing it first. `root` should be a full-rect
## Control (editor) or a CanvasLayer (runtime); both let the backdrop and anchors fill the screen.
func build_into(root: Node) -> void:
	# Remove immediately (not just queue_free) so rebuilds within one frame don't stack.
	for child: Node in root.get_children():
		root.remove_child(child)
		child.queue_free()

	root.add_child(_build_backdrop())

	# Anchors are added in list order so the draw order follows the layer order, instead of all
	# top-anchored layers stacking above all bottom-anchored ones.
	for layer: LDBackgroundLayer in layers:
		root.add_child(build_layer_node(layer))


## Builds one parallax layer: a zero-size anchor pinned to the top or bottom edge of the screen,
## holding a Parallax2D + Sprite2D. Returned so callers (e.g. the shine select's per-layer
## transition) can add/remove individual layers, not just the whole background.
static func build_layer_node(layer: LDBackgroundLayer) -> Control:
	var at_top: bool = layer.anchor == LDBackgroundLayer.Anchor.TOP
	var anchor: Control = _build_anchor(at_top)

	var parallax: Parallax2D = Parallax2D.new()
	parallax.scroll_scale = Vector2(layer.parallax, layer.parallax)
	parallax.scroll_offset = layer.offset
	parallax.autoscroll = layer.autoscroll
	parallax.follow_viewport = false
	# Cap the downward limit at y = 0 so the camera can't scroll past the bottom of the
	# parallax (mirrors hills.tscn).
	parallax.limit_end = Vector2(parallax.limit_end.x, 0.0)

	if layer.repeat and layer.texture:
		parallax.repeat_size = Vector2(layer.texture.get_width(), 0.0)
		parallax.repeat_times = 5

	var sprite: Sprite2D = Sprite2D.new()
	sprite.texture = layer.texture
	if layer.custom_color:
		# Desaturate the layer and recolor it by the modulate via the tint shader, leaving the
		# node modulate white so the color isn't applied twice.
		var mat: ShaderMaterial = ShaderMaterial.new()
		mat.shader = TINT_SHADER
		mat.set_shader_parameter(&"tint_color", layer.modulate)
		sprite.material = mat
	else:
		sprite.modulate = layer.modulate
	# Sit the sprite flush against its anchored edge: top edge on a top anchor, bottom edge on
	# a bottom anchor. The layer's offset then nudges from there.
	if layer.texture:
		var half_height: float = layer.texture.get_height() / 2.0
		sprite.position.y = half_height if at_top else -half_height

	parallax.add_child(sprite)

	anchor.add_child(parallax)
	return anchor


## A zero-size control pinned to the top-center or bottom-center of the parent, used as the origin
## for the parallax layers anchored to that edge.
static func _build_anchor(at_top: bool) -> Control:
	var anchor: Control = Control.new()
	anchor.anchor_left = 0.5
	anchor.anchor_right = 0.5
	anchor.anchor_top = 0.0 if at_top else 1.0
	anchor.anchor_bottom = anchor.anchor_top
	anchor.offset_left = 0.0
	anchor.offset_right = 0.0
	anchor.offset_top = 0.0
	anchor.offset_bottom = 0.0
	anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return anchor


func _build_backdrop() -> Control:
	var backdrop: Control
	if backdrop_type == Backdrop.GRADIENT:
		var gradient: Gradient = Gradient.new()
		gradient.set_color(0, gradient_bottom)
		gradient.set_color(1, gradient_top)
		var tex: GradientTexture2D = GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill_from = Vector2(0.0, 1.0)
		tex.fill_to = Vector2(0.0, 0.0)
		var rect: TextureRect = TextureRect.new()
		rect.texture = tex
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		backdrop = rect
	else:
		var rect: ColorRect = ColorRect.new()
		rect.color = solid_color
		backdrop = rect
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return backdrop
