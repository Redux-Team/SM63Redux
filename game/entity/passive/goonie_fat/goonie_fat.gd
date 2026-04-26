extends Entity

@export var animation_player: AnimationPlayer
@export var bounce_sfx: AudioStreamPlayer2D

var _bounce_down_tween: Tween


func _ready() -> void:
	sprite.play(&"flap")
	velocity.x = 58
	velocity.y = -17
	


func _on_bounce_area_body_entered(body: Node2D) -> void:
	if body is Entity and body.velocity.y > 0:
		body.velocity.y = -400
		animation_player.play(&"squish")
		bounce_sfx.pitch_scale = randf_range(0.85, 1.5)
		bounce_sfx.play()
		_bounce_down_tween = create_tween()
		_bounce_down_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		_bounce_down_tween.tween_property(self, "position:y", position.y + 8, 0.3)


func _on_foot_grab_area_body_entered(body: Node2D) -> void:
	if body is Player and body.velocity.y < 0:
		pass
		#body.set_attached(self, "top")
