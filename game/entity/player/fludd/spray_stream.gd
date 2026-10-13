class_name SprayStream
extends Node2D

@export var nozzle: Node2D
@export var carrier: CharacterBody2D
@export var line: Line2D
@export var splash: AnimatedParticles
@export var top_cap: Texture2D
@export var emitting: bool = false:
	set(value):
		if emitting and not value:
			_detach()
		emitting = value
@export_group("Stream")
@export var default_profile: SprayProfile
@export_custom(PROPERTY_HINT_NONE, "suffix:/s") var sample_rate: float = 60.0
@export_range(0.0, 45.0, 0.1, "degrees") var spread: float = 1.5
@export_group("Collision")
@export_flags_2d_physics var collision_mask: int = 2
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var splash_interval: float = 0.06
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var impact_hold: float = 0.05
@export_group("Drawing")
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var min_point_spacing: float = 1.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var start_offset: float = 6.0
@export_group("Breaking")
@export_range(0.0, 180.0, 0.1, "degrees") var break_angle: float = 45.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var break_distance: float = 0.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var break_cooldown: float = 0.1
@export_group("Tail")
@export var tail_width_scale: float = 1.5
@export_range(0.0, 1.0) var tail_taper_start: float = 0.7
@export_range(0.0, 1.0) var tail_fade_start: float = 0.55
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var tail_halflife: float = 0.06
@export_group("Flow")
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var flow_speed: float = 280.0
@export var wobble_amount: float = 0.06
@export var wobble_frequency: float = 1.0
@export var wobble_speed: float = 8.0

var power_ratio: float = 1.0
var profile: SprayProfile:
	set(value):
		if value != profile:
			_detach()
		profile = value

var _segments: Array[Segment] = []
var _active: Segment
var _emit_clock: float = 0.0
var _splash_clock: float = 0.0
var _previous: Transform2D
var _current: Transform2D
var _carrier_previous: Vector2
var _carrier_current: Vector2


func _ready() -> void:
	top_level = true
	global_transform = Transform2D.IDENTITY
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	process_physics_priority = 1
	line.visible = false
	_current = nozzle.global_transform
	_previous = _current
	_carrier_current = carrier.global_position if carrier else _current.origin
	_carrier_previous = _carrier_current


func _physics_process(delta: float) -> void:
	_previous = _current
	_current = nozzle.global_transform
	_carrier_previous = _carrier_current
	_carrier_current = carrier.global_position if carrier else _current.origin
	if _active and _is_discontinuous():
		_break(delta)
	_splash_clock = maxf(_splash_clock - delta, 0.0)
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	for segment: Segment in _segments:
		_advance(segment, space, delta)
	
	if emitting:
		_emit(delta)
	else:
		_emit_clock = 0.0
	
	_prune()


func _process(delta: float) -> void:
	var fraction: float = Engine.get_physics_interpolation_fraction() if nozzle.is_physics_interpolated_and_enabled() else 1.0
	var origin: Vector2 = _get_origin(_previous).lerp(_get_origin(_current), fraction)
	for segment: Segment in _segments:
		_draw_segment(segment, origin, fraction, delta)
	
	var shader: ShaderMaterial = line.material as ShaderMaterial
	shader.set_shader_parameter(&"body_region", _get_region(line.texture))
	shader.set_shader_parameter(&"top_region", _get_region(top_cap))
	shader.set_shader_parameter(&"uv_length", line.width * _get_width_padding() * line.texture.get_width() / line.texture.get_height())
	shader.set_shader_parameter(&"width_padding", _get_width_padding())
	shader.set_shader_parameter(&"tail_width_scale", tail_width_scale)
	shader.set_shader_parameter(&"tail_taper_start", tail_taper_start)
	shader.set_shader_parameter(&"tail_fade_start", tail_fade_start)
	shader.set_shader_parameter(&"body_length", _get_natural_length(line.texture))
	shader.set_shader_parameter(&"top_length", _get_natural_length(top_cap))
	shader.set_shader_parameter(&"flow_speed", flow_speed)
	shader.set_shader_parameter(&"wobble_amount", wobble_amount)
	shader.set_shader_parameter(&"wobble_frequency", wobble_frequency)
	shader.set_shader_parameter(&"wobble_speed", wobble_speed)


func _get_origin(nozzle_transform: Transform2D) -> Vector2:
	return nozzle_transform.origin - nozzle_transform.y.normalized() * start_offset


func _get_width_padding() -> float:
	return maxf(tail_width_scale, 1.0)


func _get_region(texture: Texture2D) -> Vector4:
	var atlas: AtlasTexture = texture as AtlasTexture
	if not atlas:
		return Vector4(0.0, 0.0, 1.0, 1.0)
	var size: Vector2 = atlas.atlas.get_size()
	return Vector4(atlas.region.position.x / size.x, atlas.region.position.y / size.y, atlas.region.size.x / size.x, atlas.region.size.y / size.y)


func _get_natural_length(texture: Texture2D) -> float:
	return line.width * texture.get_height() / texture.get_width() if texture else 0.0


func _is_discontinuous() -> bool:
	var turn: float = absf(_previous.y.angle_to(_current.y))
	var shift: Vector2 = (_current.origin - _carrier_current) - (_previous.origin - _carrier_previous)
	return turn > deg_to_rad(break_angle) or carrier and break_distance > 0.0 and shift.length() > break_distance


func _break(delta: float) -> void:
	if _active.age < break_cooldown:
		_active.samples.clear()
	else:
		while not _active.samples.is_empty() and _active.samples.front().age <= delta:
			_active.samples.pop_front()
		_detach()
	_previous = _current


func _detach() -> void:
	if not _active:
		return
	
	_active.attached = false
	_active = null


func _emit(delta: float) -> void:
	if not _active:
		_active = Segment.new(line.duplicate() as Line2D, profile if profile else default_profile)
		_active.line.visible = true
		_active.line.width = line.width * _get_width_padding()
		add_child(_active.line)
		_segments.append(_active)
	
	var origin: Vector2 = _get_origin(_current)
	var direction: Vector2 = _current.y.normalized()
	var source_velocity: Vector2 = (_carrier_current - _carrier_previous) / delta
	var interval: float = 1.0 / sample_rate
	_emit_clock += delta
	while _emit_clock >= interval:
		_emit_clock -= interval
		var sample: Sample = Sample.new()
		sample.age = _emit_clock
		sample.velocity = direction.rotated(deg_to_rad(randf_range(-spread, spread))) * _active.profile.speed + source_velocity * _active.profile.inherit_velocity
		sample.position = origin + sample.velocity * sample.age + 0.5 * _active.profile.gravity * sample.age * sample.age
		sample.previous = sample.position - (origin - _get_origin(_previous))
		_active.samples.push_front(sample)


func _advance(segment: Segment, space: PhysicsDirectSpaceState2D, delta: float) -> void:
	segment.age += delta
	segment.impact_time = maxf(segment.impact_time - delta, 0.0)
	var reach: float = 0.0
	var last: Vector2 = _get_origin(_current)
	for index: int in segment.samples.size():
		var sample: Sample = segment.samples.get(index)
		var next: Vector2 = sample.position + sample.velocity * delta + 0.5 * segment.profile.gravity * delta * delta
		var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters2D.create(sample.position, next, collision_mask))
		if segment.attached or index > 0:
			reach += last.distance_to(next if hit.is_empty() else hit.get("position"))
		
		if reach > segment.profile.max_length:
			_move(sample, next, segment.profile.gravity, delta)
			segment.samples.resize(index + 1)
			return
		
		if not hit.is_empty():
			_impact(segment, hit.get("position"))
			segment.samples.resize(index)
			return
		
		_move(sample, next, segment.profile.gravity, delta)
		last = next
	
	while not segment.samples.is_empty() and segment.samples.back().age > segment.profile.lifetime:
		segment.samples.pop_back()


func _move(sample: Sample, next: Vector2, gravity: Vector2, delta: float) -> void:
	sample.previous = sample.position
	sample.position = next
	sample.velocity += gravity * delta
	sample.age += delta


func _impact(segment: Segment, point: Vector2) -> void:
	segment.impact = point
	segment.impact_time = impact_hold
	if _splash_clock > 0.0:
		return
	
	_splash_clock = splash_interval
	splash.global_position = point
	splash.burst()


func _prune() -> void:
	for index: int in range(_segments.size() - 1, -1, -1):
		var segment: Segment = _segments.get(index)
		if not segment.attached and segment.samples.is_empty():
			segment.line.queue_free()
			_segments.remove_at(index)


func _draw_segment(segment: Segment, origin: Vector2, fraction: float, delta: float) -> void:
	var points: PackedVector2Array = PackedVector2Array()
	if segment.attached:
		points.append(origin)
	for sample: Sample in segment.samples:
		_append_spaced(points, sample.previous.lerp(sample.position, fraction))
	var hitting: bool = segment.impact_time > 0.0
	if hitting:
		_append_spaced(points, segment.impact)
	
	var limited: PackedVector2Array = points if hitting else _limit(points, segment.profile.max_length)
	segment.tail = Motion.damp(segment.tail, 0.0 if hitting else 1.0, tail_halflife, delta)
	segment.line.points = limited if limited.size() > 1 else PackedVector2Array()
	segment.line.set_instance_shader_parameter(&"line_length", _get_length(limited))
	segment.line.set_instance_shader_parameter(&"tail_amount", segment.tail)
	if segment.attached:
		segment.width = lerpf(segment.profile.empty_width_scale, 1.0, power_ratio)
	segment.line.set_instance_shader_parameter(&"stream_width", segment.width)


func _limit(points: PackedVector2Array, max_length: float) -> PackedVector2Array:
	var limited: PackedVector2Array = PackedVector2Array()
	var length: float = 0.0
	for index: int in points.size():
		var point: Vector2 = points.get(index)
		if index > 0:
			var previous: Vector2 = points.get(index - 1)
			var step: float = previous.distance_to(point)
			if length + step > max_length:
				limited.append(previous.move_toward(point, max_length - length))
				return limited
			length += step
		limited.append(point)
	return limited


func _get_length(points: PackedVector2Array) -> float:
	var length: float = 0.0
	for index: int in range(1, points.size()):
		length += points.get(index - 1).distance_to(points.get(index))
	return length


func _append_spaced(points: PackedVector2Array, point: Vector2) -> void:
	if points.is_empty() or points.get(points.size() - 1).distance_to(point) >= min_point_spacing:
		points.append(point)


class Segment:
	var line: Line2D
	var samples: Array[Sample] = []
	var profile: SprayProfile
	var attached: bool = true
	var tail: float = 1.0
	var width: float = 1.0
	var age: float = 0.0
	var impact: Vector2
	var impact_time: float = 0.0
	
	
	func _init(segment_line: Line2D, segment_profile: SprayProfile) -> void:
		line = segment_line
		profile = segment_profile


class Sample:
	var position: Vector2
	var previous: Vector2
	var velocity: Vector2
	var age: float
