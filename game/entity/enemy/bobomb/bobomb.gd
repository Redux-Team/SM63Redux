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
	if not area.has_meta("player") or machine.get_state_name() in [&"Strike", &"Kaboom"]:
		return
	
	var player: Player = area.owner
	sprite.flip_h = player.global_position.x < global_position.x
	target = player
	machine.change_state(&"Chase")
	player_check.set_deferred("monitoring", false)
