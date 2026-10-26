class_name PauseScreen
extends CanvasLayer

static var _inst: PauseScreen

@export var animation_player: AnimationPlayer
@export var audio_stream_player: AudioStreamPlayer
@export var resume_button: Button

var _pause_tween: Tween
var _is_open: bool = false
var _time_scale: float = -1.0


func _enter_tree() -> void:
	visible = false
	_inst = self


func _exit_tree() -> void:
	_inst = null


func _input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		assert(is_instance_valid(_inst))
		if not _is_open:
			open()
		else:
			close()


func open() -> void:
	if _is_open:
		return
	
	_is_open = true
	_time_scale = Engine.time_scale
	
	audio_stream_player.play()
	animation_player.play(&"open")
	
	resume_button.grab_focus()
	_pause_tween = create_tween().set_parallel()
	_pause_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	#_pause_tween.tween_property(Engine, ^"time_scale", 0.0, 0.1)
	_pause_tween.chain().tween_property(get_tree(), ^"paused", true, 0)


func close() -> void:
	if not _is_open:
		return
	
	_is_open = false
	
	animation_player.play(&"close")
	
	_pause_tween = create_tween().set_parallel()
	_pause_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	#_pause_tween.tween_property(Engine, ^"time_scale", _time_scale, 0.1)
	_pause_tween.chain().tween_property(get_tree(), ^"paused", false, 0)
