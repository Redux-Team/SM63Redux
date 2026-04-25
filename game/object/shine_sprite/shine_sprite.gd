extends LevelObject

@export var sprite: SmartSprite2D
@export var audio_stream_player_2d: AudioStreamPlayer2D


func _ready() -> void:
	sprite.play(&"spin")

# TODO this will obviously be improved when the player is fully complete
func _on_area_2d_body_entered(body: Node2D) -> void:
	if body is Player:
		sprite.hide()
		audio_stream_player_2d.stop()
		$ParticleEmitter.emitting = false
