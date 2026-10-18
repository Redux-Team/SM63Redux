class_name PlayerDetectorComponent
extends EntityComponent


@export var detection_area: Area2D
@export var alert_state: StringName = &"Chase"
@export var ignored_states: Array[StringName] = []
@export_group("Losing Target")
@export var aggro_states: Array[StringName] = []
@export var lost_state: StringName

var target: Player

var _hidden: Player


func _ready() -> void:
	set_physics_process(false)
	if detection_area:
		detection_area.area_entered.connect(_on_detection_area_entered)
		detection_area.area_exited.connect(_on_detection_area_exited)


func _physics_process(_delta: float) -> void:
	if target and not target.is_detectable():
		forget()
	elif _hidden and _hidden.is_detectable():
		_detect(_hidden)

	set_physics_process(target != null or _hidden != null)


func has_target() -> bool:
	return is_instance_valid(target) and target.is_detectable()


func forget() -> void:
	target = null
	detection_area.set_deferred(&"monitoring", true)
	if not lost_state.is_empty() and entity.machine.get_state_name() in aggro_states:
		entity.machine.change_state(lost_state)


func _detect(player: Player) -> void:
	if not enabled or entity.machine.get_state_name() in ignored_states:
		return

	_hidden = null
	target = player
	entity.sprite.flip_h = target.global_position.x < entity.global_position.x
	entity.machine.change_state(alert_state)
	detection_area.set_deferred(&"monitoring", false)
	set_physics_process(true)


func _on_detection_area_entered(area: Area2D) -> void:
	var player: Player = area.owner as Player
	if not enabled or not area.has_meta("player") or not player:
		return

	if player.is_detectable():
		_detect(player)
	else:
		_hidden = player
		set_physics_process(true)


func _on_detection_area_exited(area: Area2D) -> void:
	if _hidden and area.owner == _hidden:
		_hidden = null
