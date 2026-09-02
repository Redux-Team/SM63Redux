class_name LDViewportGrid
extends Control

## The editor's background grid, drawn as two tiled blits rather than a fullscreen shader.
## Hardware texture repeat reproduces the pattern exactly, so the pass costs one cached fetch per
## pixel instead of two plus the world-space math the shader redid for every one of them, and it
## batches with the rest of the canvas instead of switching pipelines for a single quad. It can
## also drop the tiled blit outright once the fade has taken the grid below a visible alpha, which
## a shader cannot decide from the inside. Integrated GPUs are the ones that notice.
##
## Drawn in the active layer's own coordinates rather than the world's, which is what lets the grid
## ride along with a parallaxing layer and stretch with a scaled one, instead of drawing a fixed
## grid the layer's contents slide across.


## Alpha below which the blit would round away to nothing on an 8-bit target anyway.
const ALPHA_EPSILON: float = 1.0 / 255.0


@export var texture: Texture2D
@export var bg_modulate: Color = Color(0, 0, 0, 0.2)
@export var origin_modulate: Color = Color(0, 0, 0, 1)
## Scaled cell size below which the grid has thinned out to nothing. A scaled-down layer draws a
## scaled-down grid, so it fades at the zoom its own cells become too small to read at, not the one
## the world grid would.
@export_range(0.0, 4.0) var fade_threshold: float = 1.0


var _camera_zoom: Vector2 = Vector2.ONE
var _layer_offset: Vector2 = Vector2.ZERO
var _layer_scale: Vector2 = Vector2.ONE


## Seats the grid over exactly the region the camera can see, in world coordinates. It sits inside
## the layer stack so it can be z-ordered against the layers, which means covering the view is a
## matter of moving and resizing it rather than anchoring it to the screen. The rect also culls the
## node, so it has to keep tracking the camera rather than staying put.
func set_camera(pos: Vector2, zoom: Vector2) -> void:
	var view: Vector2 = get_viewport_rect().size / zoom
	
	_camera_zoom = zoom
	position = pos - view * 0.5
	size = view
	queue_redraw()


## Where this node's origin actually lands. A [Control] in world space has its canvas origin
## rounded to whole units by the engine's control-to-pixel snapping, and one unit here is several
## screen pixels once zoomed in - so drawing against the unrounded [member Control.position] left
## the grid sliding by the rounding residual on every camera move.
func _snapped_origin() -> Vector2:
	return position.round()


## Change-guarded because [LDViewport] pushes the active layer's live transform every frame, and a
## layer that has not moved should cost one comparison rather than a redraw.
func set_layer_transform(offset: Vector2, layer_scale: Vector2) -> void:
	if offset == _layer_offset and layer_scale == _layer_scale:
		return
	
	_layer_offset = offset
	_layer_scale = layer_scale
	queue_redraw()


func _draw() -> void:
	if not texture or is_zero_approx(_layer_scale.x) or is_zero_approx(_layer_scale.y):
		return
	
	# Drawing in the layer's own space is what lands the tiling on the layer's cell boundaries
	# whatever the layer is doing; the node itself already sits in world space under the camera.
	var offset: Vector2 = _layer_offset - _snapped_origin()
	draw_set_transform(offset, 0.0, _layer_scale)
	
	var cell: Vector2 = texture.get_size()
	var fade: float = smoothstep(0.0, fade_threshold, absf(_camera_zoom.x * _layer_scale.x))
	var bg: Color = Color(bg_modulate, bg_modulate.a * fade)
	
	if bg.a > ALPHA_EPSILON:
		var near: Vector2 = -offset / _layer_scale
		var far: Vector2 = (size - offset) / _layer_scale
		var start: Vector2 = (near.min(far) / cell).floor() * cell
		var end: Vector2 = (near.max(far) / cell).ceil() * cell
		draw_texture_rect(texture, Rect2(start, end - start), true, bg)
	
	# The highlighted cell is the one ending at the layer's origin, which is where the tile phase
	# the rest of the grid is laid out from puts it.
	draw_texture_rect(texture, Rect2(-cell, cell), false, origin_modulate)
