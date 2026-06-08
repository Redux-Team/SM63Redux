@icon("uid://dl48gyw37ryc4")
class_name HurtBox
extends Area2D

signal damaged(source_hitbox: HitBox)

@export_group("Filtering")
## Hitbox IDs that are always rejected before component matching.
@export var ignored_hitbox_ids: PackedStringArray
## Damage types that are always rejected before component matching.
@export var ignored_damage_types: Array[HitBox.DamageType]

@export_group("Components")
## Evaluated in order; first match wins.
@export var components: Array[HurtBoxComponent]

@export_group("Defaults")
@export var default_damage_state: StringName
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "default_knockback") var has_default_knockback: bool = false
@export var default_knockback: Vector2 = Vector2(150, 135)
@export_custom(PROPERTY_HINT_GROUP_ENABLE, "disable_on_hit") var disable_on_hit: bool = false
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var disable_on_hit_duration: float = 0.0

@export_group("Blink")
@export var blink_targets: Array[CanvasItem] = []
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var blink_interval: float = 0.08
@export var blink_alpha: float = 0.2

var _disable_timers: Array[SceneTreeTimer] = []
var _hit_this_frame: bool = false
var _blink_tween: Tween


func _init() -> void:
	collision_layer = 1 << 5
	collision_mask = 1 << 4
	area_entered.connect(_on_area_entered)


func _on_area_entered(area: Area2D) -> void:
	if _hit_this_frame or area is not HitBox:
		return
	var hitbox: HitBox = area as HitBox
	
	if not hitbox.is_valid():
		return
	if hitbox.hitbox_ids.any(func(id: String) -> bool: return id in ignored_hitbox_ids):
		return
	if hitbox.damage_type in ignored_damage_types:
		return
	
	for component: HurtBoxComponent in components:
		if not component.matches(hitbox, self, owner as Entity if owner is Entity else null):
			continue
		if owner is Entity:
			component.process(hitbox, self, owner as Entity)
		var should_disable: bool = component.disable_on_hit if component.disable_on_hit else disable_on_hit
		if should_disable:
			var duration: float = hitbox.override_disable_duration if hitbox.override_disable_on_hit else (component.disable_on_hit_duration if component.disable_on_hit else disable_on_hit_duration)
			_push_disable_timer(duration)
		_hit_this_frame = true
		damaged.emit(hitbox)
		return


func _process(_delta: float) -> void:
	_hit_this_frame = false


func _push_disable_timer(duration: float) -> void:
	disable()
	if duration <= 0.0:
		return
	var timer: SceneTreeTimer = get_tree().create_timer(duration)
	_disable_timers.append(timer)
	timer.timeout.connect(_on_disable_timer_expired.bind(timer))


func _on_disable_timer_expired(timer: SceneTreeTimer) -> void:
	_disable_timers.erase(timer)
	if _disable_timers.is_empty():
		enable()


func enable(time: float = 0.0) -> void:
	set_deferred(&"monitoring", true)
	stop_blink()
	if time > 0.0:
		_push_disable_timer(time)


func disable() -> void:
	set_deferred(&"monitoring", false)
	start_blink()


func start_blink() -> void:
	if blink_targets.is_empty() or _blink_tween != null:
		return
	_blink_tween = create_tween().set_loops()
	for target: CanvasItem in blink_targets:
		_blink_tween.tween_property(target, "modulate", Color(1.0, 1.0, 1.0, blink_alpha), blink_interval)
		_blink_tween.tween_property(target, "modulate", Color.WHITE, blink_interval)


func stop_blink() -> void:
	if _blink_tween == null:
		return
	_blink_tween.kill()
	_blink_tween = null
	for target: CanvasItem in blink_targets:
		target.modulate = Color.WHITE
