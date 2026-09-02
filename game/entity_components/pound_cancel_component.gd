class_name PoundCancelComponent
extends Node


@export var hurt_box: HurtBox
@export var accepted_hitbox_id: String = "ground_pound"


func _ready() -> void:
	if hurt_box:
		hurt_box.damaged.connect(_on_hurt_box_damaged)


func _on_hurt_box_damaged(source_hitbox: HitBox) -> void:
	if not accepted_hitbox_id in source_hitbox.hitbox_ids:
		return
	
	var player: Player = source_hitbox.owner as Player
	if player:
		player.request_pound_cancel()
