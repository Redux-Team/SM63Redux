class_name BobOmb
extends Entity

@export var fuse: SmartSprite2D
@export var key: SmartSprite2D
@export var player_check: Area2D

var target: Player


func _ready() -> void:
	super()
	key.play()


func _on_sprite_frame_changed() -> void:
	if sprite.current_frame in [1, 2, 5, 6]:
		fuse.offset = Vector2(0, 1)
	else:
		fuse.offset = Vector2.ZERO
	
	key.offset = fuse.offset


func _on_player_check_area_entered(area: Area2D) -> void:
	if area.has_meta("player") and state_machine.get_current_state().get_internal_name() not in ["strike", "kaboom"]:
		var player: Player = area.owner
		var relative: int = sign(player.global_position.x - global_position.x)
		sprite.flip_h = false if relative >= 0 else true
		target = player
		state_machine.change_state("chase")
		player_check.set_deferred("monitoring", false)
