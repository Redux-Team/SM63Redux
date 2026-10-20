class_name InvincibleCap
extends CapMode

@export var silhouette_material: Material
@export var silhouette_parts: Array[Sprite2D] = []
@export var hitbox: HitBox
@export var trail: AfterimageTrail
@export var ground_speed_scale: float = 1.0
@export_group("Trail")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var trail_shrink_time: float = 4.0
@export_range(0.0, 1.0, 0.01) var trail_min_scale: float = 0.4

var _overlay: CanvasGroup


func _enter() -> void:
	_overlay = CanvasGroup.new()
	_overlay.material = silhouette_material
	_overlay.z_as_relative = false
	_overlay.z_index = RenderingServer.CANVAS_ITEM_Z_MAX
	player.add_child(_overlay)
	for part: Sprite2D in silhouette_parts:
		var mirror: SpriteMirror = SpriteMirror.new()
		mirror.target = part
		_overlay.add_child(mirror)
	
	hitbox.enable()
	trail.process_mode = Node.PROCESS_MODE_INHERIT
	super()
	_sync_trail()


func has_top_speed_run() -> bool:
	return true


func _tick(delta: float) -> void:
	super(delta)
	_sync_trail()


func _exit() -> void:
	super()
	hitbox.disable()
	trail.process_mode = Node.PROCESS_MODE_DISABLED
	_overlay.queue_free()
	_overlay = null


func _show_look(shown: bool) -> void:
	super(shown)
	if _overlay:
		_overlay.self_modulate.a = 1.0 if shown else 0.0


func is_intangible() -> bool:
	return true


func is_lethal() -> bool:
	return true


func _sync_trail() -> void:
	if not is_timed() or trail_shrink_time <= 0.0:
		trail.lifetime_scale = 1.0
		return
	
	trail.lifetime_scale = lerpf(trail_min_scale, 1.0, clampf((duration - time) / trail_shrink_time, 0.0, 1.0))
