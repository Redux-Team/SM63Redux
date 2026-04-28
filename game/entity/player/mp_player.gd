extends AnimatedSprite2D

@export var doll: SmartSprite2D


func _process(_delta: float) -> void:
	rotation = doll.rotation
	
	flip_h = doll.flip_h
	flip_v = doll.flip_v
	
	animation = doll.current_animation
	frame = doll.current_frame
