@abstract class_name CapMode
extends Mode

@export_custom(PROPERTY_HINT_NONE, "suffix:s") var duration: float = 0.0
@export var material: Material
@export var material_target: CanvasItem
@export var material_exempt: Array[CanvasItem] = []
@export_group("Blink")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var blink_time: float = 4.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var blink_interval_start: float = 0.25
@export_custom(PROPERTY_HINT_NONE, "suffix:s")
var blink_interval_end: float = 0.05

var player: Player

var _blink_phase: float = 0.0
var _look_shown: bool = false
var _previous_material: Material


func _bind() -> void:
	player = host as Player


func _enter() -> void:
	_blink_phase = 0.0
	_set_look_shown(true)


func _tick(delta: float) -> void:
	var remaining: float = duration - time
	if is_timed() and blink_time > 0.0 and remaining <= blink_time:
		_blink_phase += delta / lerpf(
				blink_interval_start,
				blink_interval_end,
				1.0 - remaining / blink_time,
		)
	
	_set_look_shown(int(_blink_phase) % 2 == 0)
	if is_timed() and time >= duration:
		end()


func _exit() -> void:
	_set_look_shown(false)


func get_remaining_ratio() -> float:
	return clampf(1.0 - time / duration, 0.0, 1.0) if is_timed() else 1.0


func is_timed() -> bool:
	return duration > 0.0 and not permanent


func get_scale(attribute: StringName) -> float:
	var value: Variant = get(attribute)
	return value if value is float else 1.0


func get_animation_override(animation: StringName) -> StringName:
	return animation


func get_footstep_terrain() -> StringName:
	return &""


func get_water_fall_speed(_pounding: bool) -> float:
	return 0.0


func redirect_state(_from: StringName, to: StringName) -> StringName:
	return to


func set_flapping(_flapping: bool) -> void:
	pass


func has_top_speed_run() -> bool:
	return false


func allows_glide() -> bool:
	return false


func ignores_water() -> bool:
	return false


func is_undetectable() -> bool:
	return false


func is_intangible() -> bool:
	return false


func is_harmless() -> bool:
	return false


func is_lethal() -> bool:
	return false


func has_free_jump_chain() -> bool:
	return false


func dive_keeps_fall_speed() -> bool:
	return false


func _show_look(shown: bool) -> void:
	if not material:
		return
	
	var target: CanvasItem = material_target if material_target else player.sprite
	for item: CanvasItem in material_exempt:
		item.use_parent_material = not shown
	
	if shown:
		_previous_material = target.material
		target.material = material
	elif target.material == material:
		target.material = _previous_material


func _set_look_shown(shown: bool) -> void:
	if shown == _look_shown:
		return
	
	_look_shown = shown
	_show_look(shown)
