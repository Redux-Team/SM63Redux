class_name ShineSelect
extends CanvasLayer

## Shine select screen shown before a playtest when a level has shine scenarios. Renders the
## level's (blurred) background behind a white vignette and a carousel of spinning shine sprites,
## one per selectable scenario. Emits scenario_chosen with the picked scenario index.


signal scenario_chosen(index: int)


const SHINE_SPIN_TEXTURE: Texture2D = preload("uid://bh4jhqvk5nh4r")
const FRAME_WIDTH: int = 28
const FRAME_HEIGHT: int = 31
const SPACING: float = 128.0
## Display scale of the highlighted shine, and of the others to either side of it.
const SHINE_SCALE: float = 4.0
const UNSELECTED_SCALE: float = 2.0
## Extra scale the chosen shine grows to during its selection animation.
const SELECTION_SCALE_BOOST: float = 1.2
## How long the selection (jump/fall) animation runs (the y-velocity curve's time domain).
const SELECTION_DURATION: float = 1.2
## Seconds into the selection animation when the shine-out transition fires (kept short so it
## overlaps the jump instead of waiting for the whole arc).
const TRANSITION_TIME: float = 0.35
## Upward drift of the scenario name (px/sec) as it fades out on selection.
const TEXT_RISE_SPEED: float = 160.0
## How quickly the non-chosen shines fade out / the chosen shine grows once a shine is picked.
const FADE_RATE: float = 12.0
## Virtual camera pan speed (pixels/sec, negative = left); each layer scrolls by this times its
## own parallax factor, so the backdrop drifts with proper depth.
const BACKGROUND_SCROLL: float = -150.0
## How far (px) the scenario name rises while cycling, and the duration of each half of the cycle.
const NAME_CYCLE_RISE: float = 22.0
const NAME_CYCLE_TIME: float = 0
## How long a background transition (backdrop color tween + per-layer fades) takes.
const BG_TRANSITION_TIME: float = 0.2


@export var bg_layer: Control
@export var name_label: Label
@export var carousel: Node2D
@export var music: AudioStreamPlayer
## Spin speed (AnimatedSprite2D.speed_scale) over the selection animation, sampled 0..1.
@export var selection_spin_speed_curve: Curve
## Vertical velocity (px/sec, negative = up) over the selection animation, sampled 0..1.
@export var selection_y_velocity_curve: Curve


## Each entry: { "index": int, "name": String, "area_name": String }
var _scenarios: Array[Dictionary] = []
var _level_data: Dictionary = {}
## The background dict currently shown, so cycling only transitions when the next one differs.
var _current_bg: Dictionary = {}
## The backdrop is always a gradient (a solid colour is just both stops equal), so its transition is
## a clean colour tween. Parallax layers are kept live as an ordered list of { "sig", "node",
## "tween" } so layers shared between two areas stay put (no re-fade) and only differing layers fade
## in/out. A list (not a dict) so duplicate layers - same texture, same signature - each keep their
## own node instead of colliding.
var _backdrop_gradient: Gradient
var _layers: Array[Dictionary] = []
var _backdrop_tween: Tween
var _selected: int = 0
var _shines: Array[AnimatedSprite2D] = []
var _chosen: int = -1
var _select_time: float = 0.0
var _emitted: bool = false
var _name_tween: Tween
var _name_rest_y: float
var _name_rest_captured: bool = false


## Builds the screen from the saved level dict and the list of shine scenarios to offer.
func setup(level_data: Dictionary, scenarios: Array[Dictionary]) -> void:
	_scenarios = scenarios
	_level_data = level_data
	_selected = 0
	_current_bg = _bg_dict_for(_scenario_area(0))
	_build_initial_background(_current_bg)
	_build_carousel()
	_layout(true)
	_update_name()
	if music.stream:
		music.play()


## The area linked to the scenario shown at `index` (empty = the level's first area).
func _scenario_area(index: int) -> String:
	if index < 0 or index >= _scenarios.size():
		return ""
	return str(_scenarios[index].get("area_name", ""))


## Resolves the background dict for an area: the matching area's "background", else the first area's,
## else the legacy level-wide editor.background.
func _bg_dict_for(area_name: String) -> Dictionary:
	var areas: Variant = _level_data.get("areas", [])
	if areas is Array:
		var first: Dictionary = {}
		for entry: Variant in areas:
			if not entry is Dictionary:
				continue
			if first.is_empty():
				first = entry
			if not area_name.is_empty() and str((entry as Dictionary).get("name", "")) == area_name:
				var bg: Variant = (entry as Dictionary).get("background", {})
				return bg if bg is Dictionary else {}
		if not first.is_empty():
			var bg_first: Variant = first.get("background", {})
			if bg_first is Dictionary and not (bg_first as Dictionary).is_empty():
				return bg_first
	var editor: Variant = _level_data.get("editor", {})
	if editor is Dictionary:
		var legacy: Variant = (editor as Dictionary).get("background", {})
		if legacy is Dictionary:
			return legacy
	return {}


## A layer's visual identity for keeping shared layers across transitions: two layers that look the
## same are "the same" and are kept rather than re-faded. Only visual fields count - the id and
## display name are editor metadata, so a preset-background layer and an identical picker-added one
## still match.
func _layer_signature(layer: LDBackgroundLayer) -> String:
	var data: Dictionary = layer.serialize()
	data.erase("id")
	data.erase("display_name")
	return str(data)


## The backdrop's [top, bottom] colours: the gradient stops, or a solid colour duplicated so the
## backdrop is always a gradient and transitions are a clean colour tween.
func _backdrop_colors(bg: LDBackground) -> Array:
	if bg.backdrop_type == LDBackground.Backdrop.GRADIENT:
		return [bg.gradient_top, bg.gradient_bottom]
	return [bg.solid_color, bg.solid_color]


## Builds the initial backdrop (a full-rect gradient) and parallax layers directly into bg_layer.
func _build_initial_background(bg_dict: Dictionary) -> void:
	var bg: LDBackground = LDBackgroundDB.resolve(bg_dict) if not bg_dict.is_empty() else null
	var cols: Array = _backdrop_colors(bg) if bg else [Color.BLACK, Color.BLACK]

	_backdrop_gradient = Gradient.new()
	_backdrop_gradient.set_color(0, cols[1])
	_backdrop_gradient.set_color(1, cols[0])
	var tex: GradientTexture2D = GradientTexture2D.new()
	tex.gradient = _backdrop_gradient
	tex.fill_from = Vector2(0.0, 1.0)
	tex.fill_to = Vector2(0.0, 0.0)
	var backdrop: TextureRect = TextureRect.new()
	backdrop.texture = tex
	backdrop.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg_layer.add_child(backdrop)

	if bg:
		for layer: LDBackgroundLayer in bg.layers:
			var node: Control = _spawn_layer(layer)
			_layers.append({"sig": _layer_signature(layer), "node": node, "tween": null})


## Builds one parallax layer node into bg_layer and returns it (no tracking - caller records it).
func _spawn_layer(layer: LDBackgroundLayer) -> Control:
	var node: Control = LDBackground.build_layer_node(layer)
	bg_layer.add_child(node)
	_apply_parallax_scroll(node)
	return node


## Sets a layer's opacity: the node modulate (fades plain sprites) plus the tint shader's `fade`
## uniform on any custom-color sprite in the layer (whose shader bypasses modulate). `alpha` comes
## first so it can be tween_method's value with the node bound after it.
func _set_layer_alpha(alpha: float, node: Control) -> void:
	node.modulate.a = alpha
	_set_tinted_fade(node, alpha)


func _set_tinted_fade(node: Node, alpha: float) -> void:
	var sprite: Sprite2D = node as Sprite2D
	if sprite and sprite.material is ShaderMaterial and (sprite.material as ShaderMaterial).shader == LDBackground.TINT_SHADER:
		(sprite.material as ShaderMaterial).set_shader_parameter(&"fade", alpha)
	for child: Node in node.get_children():
		_set_tinted_fade(child, alpha)


## Fades a layer's opacity to `to_alpha` over the transition (freeing it after if asked) and returns
## the tween, so the caller can kill it if the layer's direction reverses mid-fade.
func _fade_layer(node: Control, to_alpha: float, free_after: bool) -> Tween:
	var fade: Tween = create_tween()
	fade.tween_method(_set_layer_alpha.bind(node), node.modulate.a, to_alpha, BG_TRANSITION_TIME)
	if free_after:
		fade.tween_callback(node.queue_free)
	return fade


## Transitions to the new scenario's background: tween the backdrop colours, keep shared parallax
## layers untouched (matched one-for-one so duplicates each keep their node), fade in layers that
## are new, and fade out (then free) layers that are gone.
func _maybe_swap_background() -> void:
	var new_bg: Dictionary = _bg_dict_for(_scenario_area(_selected))
	if hash(new_bg) == hash(_current_bg):
		return
	_current_bg = new_bg
	var bg: LDBackground = LDBackgroundDB.resolve(new_bg) if not new_bg.is_empty() else null

	# Backdrop: tween the gradient stops to the new colours (always a clean colour transition).
	var cols: Array = _backdrop_colors(bg) if bg else [Color.BLACK, Color.BLACK]
	if _backdrop_tween and _backdrop_tween.is_valid():
		_backdrop_tween.kill()
	var from_top: Color = _backdrop_gradient.get_color(1)
	var from_bottom: Color = _backdrop_gradient.get_color(0)
	_backdrop_tween = create_tween()
	_backdrop_tween.tween_method(func(t: float) -> void:
		_backdrop_gradient.set_color(1, from_top.lerp(cols[0], t))
		_backdrop_gradient.set_color(0, from_bottom.lerp(cols[1], t))
	, 0.0, 1.0, BG_TRANSITION_TIME)

	# Layers: match each wanted layer to an existing node by signature (one-for-one, so duplicates
	# keep their own node); unmatched wanted layers fade in, leftover existing nodes fade out.
	var available: Array[Dictionary] = _layers.duplicate()
	var kept: Array[Dictionary] = []
	if bg:
		for layer: LDBackgroundLayer in bg.layers:
			var sig: String = _layer_signature(layer)
			var matched: int = -1
			for i: int in available.size():
				if available[i].get("sig") == sig:
					matched = i
					break
			if matched >= 0:
				kept.append(available[matched])
				available.remove_at(matched)
			else:
				var node: Control = _spawn_layer(layer)
				_set_layer_alpha(0.0, node)
				kept.append({"sig": sig, "node": node, "tween": _fade_layer(node, 1.0, false)})

	# Leftover existing layers are no longer wanted: kill any in-progress fade (so it doesn't fight
	# the fade-out), then fade them out and free them.
	for entry: Dictionary in available:
		var prev: Tween = entry.get("tween")
		if prev and prev.is_valid():
			prev.kill()
		_fade_layer(entry.get("node"), 0.0, true)

	# Keep draw order matching the new layer order (the backdrop stays at child 0).
	for i: int in kept.size():
		bg_layer.move_child(kept[i].get("node"), i + 1)

	_layers = kept


## Slides each parallax layer by the pan speed scaled by its own parallax factor (on top of any
## autoscroll the layer already has), so the backdrop drifts with depth - no camera, so the
## carousel and UI stay put.
func _apply_parallax_scroll(node: Node) -> void:
	for child: Node in node.get_children():
		if child is Parallax2D:
			var layer: Parallax2D = child as Parallax2D
			layer.autoscroll.x += BACKGROUND_SCROLL * layer.scroll_scale.x
		_apply_parallax_scroll(child)


func _build_carousel() -> void:
	var frames: SpriteFrames = _make_shine_frames()
	for scenario: Dictionary in _scenarios:
		var shine: AnimatedSprite2D = AnimatedSprite2D.new()
		shine.sprite_frames = frames
		shine.play(&"spin")
		carousel.add_child(shine)
		_shines.append(shine)


func _make_shine_frames() -> SpriteFrames:
	var frames: SpriteFrames = SpriteFrames.new()
	frames.add_animation(&"spin")
	frames.set_animation_loop(&"spin", true)
	frames.set_animation_speed(&"spin", 6.0)
	@warning_ignore("integer_division")
	var count: int = maxi(1, SHINE_SPIN_TEXTURE.get_width() / FRAME_WIDTH)
	for i: int in count:
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = SHINE_SPIN_TEXTURE
		atlas.region = Rect2(i * FRAME_WIDTH, 0, FRAME_WIDTH, FRAME_HEIGHT)
		frames.add_frame(&"spin", atlas)
	return frames


func _unhandled_input(event: InputEvent) -> void:
	# Ignore input until every screen transition (e.g. the wave-in) has finished - selecting a
	# shine mid-transition caused buggy behavior.
	if _scenarios.is_empty() or _chosen >= 0 or Singleton.is_transitioning():
		return
	if event.is_action_pressed(&"move_right") or event.is_action_pressed(&"ui_right"):
		_move(1)
	elif event.is_action_pressed(&"move_left") or event.is_action_pressed(&"ui_left"):
		_move(-1)
	elif event.is_action_pressed(&"jump") or event.is_action_pressed(&"ui_accept"):
		_begin_selection()


func _move(delta: int) -> void:
	var previous: int = _selected
	_selected = clampi(_selected + delta, 0, _scenarios.size() - 1)
	if _selected != previous:
		_cycle_name()
		_maybe_swap_background()


func _begin_selection() -> void:
	_chosen = _selected
	_select_time = 0.0
	_emitted = false


func _process(delta: float) -> void:
	if _chosen >= 0:
		_animate_selection(delta)
	else:
		_layout(false)


## The chosen shine spins up and arcs (jump then fall past the bottom) via the two curves, while
## the others fade out; when it finishes, the scenario is committed.
func _animate_selection(delta: float) -> void:
	_select_time += delta
	var t: float = clampf(_select_time / SELECTION_DURATION, 0.0, 1.0)
	var shine: AnimatedSprite2D = _shines[_chosen]
	if selection_spin_speed_curve:
		shine.speed_scale = selection_spin_speed_curve.sample(t)
	if selection_y_velocity_curve:
		shine.position.y += selection_y_velocity_curve.sample(t) * delta
	var blend: float = 1.0 - exp(-FADE_RATE * delta)
	shine.scale = shine.scale.lerp(Vector2.ONE * (SHINE_SCALE * SELECTION_SCALE_BOOST), blend)
	shine.z_index = 2

	# Fade the other shines out, and float the scenario name up and out.
	for i: int in _shines.size():
		if i != _chosen:
			_shines[i].modulate.a = lerpf(_shines[i].modulate.a, 0.0, blend)
	name_label.position.y -= TEXT_RISE_SPEED * delta
	name_label.modulate.a = lerpf(name_label.modulate.a, 0.0, blend)

	if not _emitted and _select_time >= TRANSITION_TIME:
		_emitted = true
		scenario_chosen.emit(_scenarios[_chosen].get("index", 0))


## Slides each shine toward its slot relative to the selected one, scaling/fading by distance.
func _layout(snap: bool) -> void:
	for i: int in _shines.size():
		var shine: AnimatedSprite2D = _shines[i]
		var slot: int = i - _selected
		var target_pos: Vector2 = Vector2(slot * SPACING, 0.0)
		var is_selected: bool = i == _selected
		var target_scale: Vector2 = Vector2.ONE * (SHINE_SCALE if is_selected else UNSELECTED_SCALE)
		var target_alpha: float = 1.0 if is_selected else 0.45
		if snap:
			shine.position = target_pos
			shine.scale = target_scale
			shine.modulate.a = target_alpha
		else:
			var t: float = 1.0 - exp(-18.0 * get_process_delta_time())
			shine.position = shine.position.lerp(target_pos, t)
			shine.scale = shine.scale.lerp(target_scale, t)
			shine.modulate.a = lerpf(shine.modulate.a, target_alpha, t)
		shine.z_index = 1 if is_selected else 0


func _update_name() -> void:
	name_label.text = _scenario_name(_selected)


func _scenario_name(index: int) -> String:
	var scenario: Dictionary = _scenarios[index]
	var display_name: String = str(scenario.get("name", ""))
	return display_name if not display_name.is_empty() else "Scenario %d" % int(scenario.get("index", 0))


## Cycles the scenario name when switching shines: the old name fades out while rising, then the
## new one rises up from below as it fades in.
func _cycle_name() -> void:
	if not _name_rest_captured:
		_name_rest_y = name_label.position.y
		_name_rest_captured = true
	if _name_tween and _name_tween.is_valid():
		_name_tween.kill()

	var new_name: String = _scenario_name(_selected)
	_name_tween = create_tween().set_trans(Tween.TRANS_CUBIC)
	_name_tween.tween_property(name_label, "modulate:a", 0.0, NAME_CYCLE_TIME).set_ease(Tween.EASE_IN)
	_name_tween.parallel().tween_property(name_label, "position:y", _name_rest_y - NAME_CYCLE_RISE, NAME_CYCLE_TIME).set_ease(Tween.EASE_IN)
	_name_tween.chain().tween_callback(func() -> void:
		name_label.text = new_name
		name_label.position.y = _name_rest_y + NAME_CYCLE_RISE
	)
	_name_tween.tween_property(name_label, "modulate:a", 1.0, NAME_CYCLE_TIME).set_ease(Tween.EASE_OUT)
	_name_tween.parallel().tween_property(name_label, "position:y", _name_rest_y, NAME_CYCLE_TIME).set_ease(Tween.EASE_OUT)
