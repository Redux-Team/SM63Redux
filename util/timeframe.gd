class_name Timeframe
extends Node


var _start_time: float = 0.0
var _elapsed_time: float = 0.0
var _process_frames: int = 0
var _physics_frames: int = 0
var _running: bool = false


func _init() -> void:
	start()


func _ready() -> void:
	Singleton.add_child(self)


func _process(_delta: float) -> void:
	if not _running:
		return
	_process_frames += 1


func _physics_process(_delta: float) -> void:
	if not _running:
		return
	_physics_frames += 1


func start() -> void:
	_start_time = Time.get_ticks_msec() / 1000.0
	_elapsed_time = 0.0
	_process_frames = 0
	_physics_frames = 0
	_running = true


func stop() -> void:
	if not _running:
		return
	_elapsed_time = Time.get_ticks_msec() / 1000.0 - _start_time
	_running = false


func as_seconds() -> float:
	if _running:
		return Time.get_ticks_msec() / 1000.0 - _start_time
	return _elapsed_time


func as_frames() -> int:
	return _process_frames


func as_physics_frames() -> int:
	return _physics_frames
