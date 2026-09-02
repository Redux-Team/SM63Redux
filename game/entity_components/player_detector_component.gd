class_name PlayerDetectorComponent
extends EntityComponent


@export var detection_area: Area2D
@export var alert_state: StringName = &"Chase"
@export var ignored_states: Array[StringName] = []

var target: Player


func _ready() -> void:
	if detection_area:
		detection_area.area_entered.connect(_on_detection_area_entered)


func _on_detection_area_entered(area: Area2D) -> void:
	if not enabled or not area.has_meta("player"):
		return
	if entity.machine.get_state_name() in ignored_states:
		return
	
	target = area.owner as Player
	entity.sprite.flip_h = target.global_position.x < entity.global_position.x
	entity.machine.change_state(alert_state)
	detection_area.set_deferred(&"monitoring", false)
