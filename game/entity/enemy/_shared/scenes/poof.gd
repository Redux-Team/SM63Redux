extends AnimatedSprite2D


func _ready() -> void:
	play()
	await animation_finished
	queue_free()
