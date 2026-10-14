extends Entity

@export var animation_player: AnimationPlayer
@export var bounce_sfx: AudioStreamPlayer2D

var _bounce_down_tween: Tween


func _on_init() -> void:
	sprite.play(&"flap")
	velocity = Vector2(58.0, -17.0)


func _on_bounce_area_body_entered(body: Node2D) -> void:
	var entity: Entity = body as Entity
	if entity == null or entity.velocity.y <= 0.0:
		return
	
	entity.velocity.y = -400.0
	animation_player.play(&"squish")
	bounce_sfx.pitch_scale = randf_range(0.85, 1.5)
	bounce_sfx.play()
	_bounce_down_tween = create_tween().set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
	_bounce_down_tween.tween_property(self, ^"position:y", position.y + 8.0, 0.3)
