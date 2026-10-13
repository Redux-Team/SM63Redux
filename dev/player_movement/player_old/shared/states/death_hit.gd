extends PlayerStateOld

@export var hurt_box: HurtBox


func _enter() -> void:
	player.collision_mask = 0
	player.z_index = player.death_z_index
	player.z_as_relative = false
	player.disable()
	hurt_box.stop_blink()
	hurt_box.queue_free()


func _next() -> StringName:
	return &"DeathFall" if time >= player.death_fall_delay else &""
