class_name LevelCamera
extends Camera2D

@export var target: CharacterBody2D
@export_group("Look Ahead")
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var look_ahead_time: float = 0.45
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var look_ahead_max: float = 96.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var look_ahead_halflife: float = 0.35
@export_group("Vertical Bias")
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var ground_bias: float = -20.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var fall_bias: float = 40.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px/s") var fall_threshold: float = 250.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var bias_halflife: float = 0.45


func follow(body: CharacterBody2D) -> void:
	target = body
	reparent(body, false)
	position = Vector2.ZERO
	offset = Vector2.ZERO
	reset_smoothing()


func _process(delta: float) -> void:
	if not is_instance_valid(target):
		return
	
	var lead: float = clampf(target.velocity.x * look_ahead_time, -look_ahead_max, look_ahead_max)
	offset.x = Motion.damp(offset.x, lead, look_ahead_halflife, delta)
	offset.y = Motion.damp(offset.y, _vertical_bias(), bias_halflife, delta)


func _vertical_bias() -> float:
	if target.is_on_floor():
		return ground_bias
	
	if target.velocity.y > fall_threshold:
		return fall_bias
	
	return offset.y
