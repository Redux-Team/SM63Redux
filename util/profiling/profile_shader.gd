class_name ProfileShader


const SHADER: Shader = preload("uid://d07pk64iuo33x")

const _VIEWPORT_SIZE: int = 1024
const _TEXTURE_SIZE: int = 256
const _ITERATIONS: int = 32
const _WARMUP_FRAMES: int = 6
const _BATCH_FRAMES: int = 8
const _REPS: int = 3
const _REFERENCE_MSEC: float = 4.8


static func run() -> float:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	
	if tree == null:
		return 0.0
	
	await tree.process_frame
	
	var viewport: SubViewport = _build_viewport()
	tree.root.add_child(viewport)
	await tree.process_frame
	
	for i: int in _WARMUP_FRAMES:
		RenderingServer.force_draw(false)
	
	_sync(viewport)
	
	var best: float = INF
	
	for rep: int in _REPS:
		best = minf(best, _batch(viewport))
	
	viewport.queue_free()
	
	return 1.0 - (best / _REFERENCE_MSEC)


static func _batch(viewport: SubViewport) -> float:
	var start: int = Time.get_ticks_usec()
	
	for i: int in _BATCH_FRAMES:
		RenderingServer.force_draw(false)
	
	_sync(viewport)
	
	return float(Time.get_ticks_usec() - start) / float(_BATCH_FRAMES) / 1000.0


static func _sync(viewport: SubViewport) -> void:
	var flush: Image = viewport.get_texture().get_image()
	flush.get_width()


static func _build_viewport() -> SubViewport:
	var material: ShaderMaterial = ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("noise_texture", _build_texture())
	material.set_shader_parameter("iterations", _ITERATIONS)
	
	var rect: ColorRect = ColorRect.new()
	rect.material = material
	rect.size = Vector2(_VIEWPORT_SIZE, _VIEWPORT_SIZE)
	
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(_VIEWPORT_SIZE, _VIEWPORT_SIZE)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.disable_3d = true
	viewport.add_child(rect)
	
	return viewport


static func _build_texture() -> ImageTexture:
	var stride: int = _TEXTURE_SIZE * 4
	var row: PackedByteArray = PackedByteArray()
	row.resize(stride)
	
	var state: int = 0x2F6E2B1
	
	for i: int in stride:
		state = (state * 1103515245 + 12345) & 0x7FFFFFFF
		row.set(i, (state >> 16) & 0xFF)
	
	var data: PackedByteArray = PackedByteArray()
	
	for y: int in _TEXTURE_SIZE:
		var split: int = (y * 4) % stride
		data.append_array(row.slice(split))
		data.append_array(row.slice(0, split))
	
	var image: Image = Image.create_from_data(
		_TEXTURE_SIZE, _TEXTURE_SIZE, false, Image.FORMAT_RGBA8, data
	)
	
	return ImageTexture.create_from_image(image)
