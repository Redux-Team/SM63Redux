class_name RespawnableComponent
extends Node

enum RespawnMode { COUNTDOWN, OFF_SCREEN }

@export var mode: RespawnMode = RespawnMode.COUNTDOWN
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var countdown: float = 10.0
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var off_screen_margin: float = 192.0
@export var check_interval: int = 6
@export var despawn_off_screen: bool = true
@export_custom(PROPERTY_HINT_NONE, "suffix:px") var despawn_margin: float = 384.0
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var despawn_delay: float = 3.0

var _object: GameObject
var _snapshot: ObjectData
var _waiting: bool = false
var _remaining: float = 0.0
var _frame: int = 0
var _despawning: bool = false
var _drops_coins: bool = false
var _outside: bool = false
var _outside_time: float = 0.0


func _ready() -> void:
	_object = GameObject.of(self)
	if _object == null or _object.game_root == null:
		return
	
	_snapshot = _object.to_data()
	_object.game_root.tree_exiting.connect(_on_root_exiting)
	set_physics_process(mode == RespawnMode.OFF_SCREEN and despawn_off_screen and _object.game_root is Entity)
	_adopt.call_deferred()


func _physics_process(delta: float) -> void:
	if not _waiting:
		var root: Entity = _object.game_root as Entity if is_instance_valid(_object.game_root) else null
		if root == null:
			return
		
		_frame += 1
		if _frame % check_interval == 0:
			_outside = not _view(despawn_margin).has_point(root.get_global_transform_with_canvas().origin)
		_outside_time = _outside_time + delta if _outside else 0.0
		if _outside_time >= despawn_delay:
			_despawning = true
			_drops_coins = root.drops_coins
			root.despawn()
		return
	
	match mode:
		RespawnMode.COUNTDOWN:
			_remaining -= delta
			if _remaining <= 0.0:
				_respawn()
		RespawnMode.OFF_SCREEN:
			if not _overlaps_view(off_screen_margin) and (not despawn_off_screen or _overlaps_view(despawn_margin)):
				_respawn()


func _adopt() -> void:
	if get_parent() != _object:
		reparent(_object)


func _on_root_exiting() -> void:
	var root: Node = _object.game_root
	var level: Level = Level.of(_object)
	if _waiting or level == null or level.is_queued_for_deletion() or not root.is_queued_for_deletion():
		return
	
	_waiting = true
	if not _despawning:
		_drops_coins = false
	_remaining = countdown
	set_physics_process(true)


func _view(margin: float) -> Rect2:
	return _object.get_viewport().get_visible_rect().grow(margin)


func _overlaps_view(margin: float) -> bool:
	var view: Rect2 = _view(margin)
	var bounds: Rect2 = _object.get_global_transform_with_canvas() * _object.get_local_bounds()
	return view.intersects(bounds.grow(1.0)) or view.has_point(_object.get_global_transform_with_canvas().origin)


func _respawn() -> void:
	set_physics_process(false)
	var level: Level = Level.of(_object)
	if level:
		level.respawn(_object, _snapshot, _drops_coins)
