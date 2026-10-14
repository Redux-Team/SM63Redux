class_name ScreenTransition
extends CanvasLayer

enum Type { CENTER, WAVE, FADE, BLUR }

const SHADERS: Dictionary[Type, Shader] = {
	Type.CENTER: preload("uid://dcewkclyl2vjk"),
	Type.WAVE: preload("uid://drycsk0p628ig"),
	Type.FADE: preload("uid://dt48274q57v41"),
	Type.BLUR: preload("uid://dt48274q57v41"),
}
const DEFAULT_TEXTURES: Dictionary[Type, Texture2D] = {
	Type.CENTER: preload("uid://34v4s1d3h4ag"),
	Type.WAVE: preload("uid://c0rwnbt8w3qel"),
}

@export var mask_rect: ColorRect
@export var loading_screen: LoadingScreen

var _material: ShaderMaterial
var _parameter: StringName
var _covered: float
var _revealed: float
var _duration_scale: float
var _transition_type: Tween.TransitionType
var _deferred_work: Array[Callable] = []
var _deferred_then: Array[Callable] = []


func _ready() -> void:
	_material = mask_rect.material as ShaderMaterial


func is_transitioning() -> bool:
	return mask_rect.visible


func defer_threaded(work: Callable, then: Callable = Callable()) -> bool:
	if not is_transitioning():
		return false
	
	_deferred_work.append(work)
	_deferred_then.append(then)
	return true


func play(builder: Builder) -> void:
	if is_transitioning():
		return
	
	if not builder.destination.is_empty():
		ResourceLoader.load_threaded_request(builder.destination)
	
	_setup(builder)
	mask_rect.mouse_filter = Control.MOUSE_FILTER_STOP if builder.block_input else Control.MOUSE_FILTER_IGNORE
	mask_rect.show()
	await _tween_mask(_revealed, _covered, builder.out_duration, Tween.EASE_OUT).finished
	await _settle()
	
	var hold: SceneTreeTimer = get_tree().create_timer(builder.hold_duration)
	var loading_timer: SceneTreeTimer = get_tree().create_timer(builder.loading_delay)
	loading_timer.timeout.connect(loading_screen.open)
	if builder.loading_delay <= 0.0 or builder.type == Type.BLUR:
		await loading_screen.open(builder.type == Type.BLUR)
	
	await _run_threaded(builder.tasks, builder.task_thens)
	for callable: Callable in builder.callables:
		await callable.call()
	
	var scene: PackedScene = await _await_scene(builder.destination)
	if builder.swap.is_valid():
		await builder.swap.call()
	elif scene:
		get_tree().change_scene_to_node(await _instantiate(scene))
	
	await _settle()
	while not _deferred_work.is_empty():
		var work: Array[Callable] = _deferred_work.duplicate()
		var thens: Array[Callable] = _deferred_then.duplicate()
		_deferred_work.clear()
		_deferred_then.clear()
		await _run_threaded(work, thens)
	if hold.time_left > 0.0:
		await hold.timeout
	
	loading_timer.timeout.disconnect(loading_screen.open)
	_set_mask_texture(builder.get_in_texture())
	await loading_screen.close()
	
	if builder.type == Type.WAVE:
		_material.set_shader_parameter(&"flip", false)
	
	await _tween_mask(_covered, _revealed, builder.in_duration, Tween.EASE_IN).finished
	mask_rect.hide()
	mask_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _setup(builder: Builder) -> void:
	_material.shader = SHADERS.get(builder.type)
	_set_mask_texture(builder.get_out_texture())
	_duration_scale = 1.0
	_transition_type = Tween.TRANS_LINEAR
	match builder.type:
		Type.CENTER:
			_transition_type = Tween.TRANS_CUBIC
			_parameter = &"mask_scale"
			_revealed = 10.0
			_covered = 0.0
		Type.WAVE:
			var size: Vector2 = mask_rect.get_viewport_rect().size
			var aspect: float = size.x / size.y if size.y > 0.0 else 1.0
			_material.set_shader_parameter(&"wave_scale", builder.wave_scale)
			_material.set_shader_parameter(&"aspect", aspect)
			_material.set_shader_parameter(&"flip", true)
			_parameter = &"mask_offset_y"
			_revealed = 1.0
			_covered = -aspect / builder.wave_scale
			_duration_scale = (_revealed - _covered) / 2.0
		Type.FADE:
			_parameter = &"fade"
			_revealed = 0.0
			_covered = 1.0
		Type.BLUR:
			_parameter = &"fade"
			_revealed = 0.0
			_covered = 0.0
			_duration_scale = 0.0


func _run_threaded(tasks: Array[Callable], thens: Array[Callable]) -> void:
	var task_ids: Array[int] = []
	for task: Callable in tasks:
		task_ids.append(WorkerThreadPool.add_task(task))
	
	for task_id: int in task_ids:
		while not WorkerThreadPool.is_task_completed(task_id):
			await get_tree().process_frame
		WorkerThreadPool.wait_for_task_completion(task_id)
	
	for then: Callable in thens:
		if then.is_valid():
			await then.call()


func _instantiate(scene: PackedScene) -> Node:
	var result: Array[Node] = []
	var task_id: int = WorkerThreadPool.add_task(func() -> void: result.append(scene.instantiate()))
	while not WorkerThreadPool.is_task_completed(task_id):
		await get_tree().process_frame
	WorkerThreadPool.wait_for_task_completion(task_id)
	return result.front()


func _await_scene(path: String) -> PackedScene:
	if path.is_empty():
		return null
	
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	return ResourceLoader.load_threaded_get(path) as PackedScene


func _tween_mask(from: float, to: float, duration: float, easing: Tween.EaseType) -> Tween:
	var tween: Tween = create_tween().set_trans(_transition_type).set_ease(easing)
	tween.tween_method(_set_parameter, from, to, duration * _duration_scale)
	return tween


func _set_parameter(value: float) -> void:
	_material.set_shader_parameter(_parameter, value)


func _set_mask_texture(texture: Texture2D) -> void:
	if texture:
		_material.set_shader_parameter(&"mask_texture", texture)


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


class Builder:
	var type: Type = Type.CENTER
	var out_duration: float = 0.5
	var in_duration: float = 0.8
	var hold_duration: float = 0.5
	var loading_delay: float = 0.5
	var wave_scale: float = 1.0
	var block_input: bool = true
	var texture: Texture2D
	var out_texture: Texture2D
	var in_texture: Texture2D
	var destination: String
	var swap: Callable
	var callables: Array[Callable] = []
	var tasks: Array[Callable] = []
	var task_thens: Array[Callable] = []
	
	var _transition: ScreenTransition
	
	
	func _init(transition: ScreenTransition) -> void:
		_transition = transition
	
	
	func set_type(value: Type) -> Builder:
		type = value
		return self
	
	
	func set_center() -> Builder:
		return set_type(Type.CENTER)
	
	
	func set_wave() -> Builder:
		return set_type(Type.WAVE)
	
	
	func set_fade() -> Builder:
		return set_type(Type.FADE)
	
	
	func set_blur() -> Builder:
		return set_type(Type.BLUR)
	
	
	func set_wave_scale(value: float) -> Builder:
		wave_scale = value
		return self
	
	
	func set_out_duration(value: float) -> Builder:
		out_duration = value
		return self
	
	
	func set_in_duration(value: float) -> Builder:
		in_duration = value
		return self
	
	
	func set_hold_duration(value: float) -> Builder:
		hold_duration = value
		return self
	
	
	func set_loading_delay(value: float) -> Builder:
		loading_delay = value
		return self
	
	
	func set_block_input(value: bool) -> Builder:
		block_input = value
		return self
	
	
	func set_texture(value: Texture2D) -> Builder:
		texture = value
		return self
	
	
	func set_out_texture(value: Texture2D) -> Builder:
		out_texture = value
		return self
	
	
	func set_in_texture(value: Texture2D) -> Builder:
		in_texture = value
		return self
	
	
	func set_destination(path: String) -> Builder:
		destination = path
		return self
	
	
	func set_swap(callable: Callable) -> Builder:
		swap = callable
		return self
	
	
	func load(callable: Callable) -> Builder:
		callables.append(callable)
		return self
	
	
	func add_threaded_task(work: Callable, then: Callable = Callable()) -> Builder:
		tasks.append(work)
		task_thens.append(then)
		return self
	
	
	func get_out_texture() -> Texture2D:
		return out_texture if out_texture else get_default_texture()
	
	
	func get_in_texture() -> Texture2D:
		return in_texture if in_texture else get_default_texture()
	
	
	func get_default_texture() -> Texture2D:
		return texture if texture else ScreenTransition.DEFAULT_TEXTURES.get(type)
	
	
	func done() -> void:
		_transition.play(self)
