extends PlayerState

@export var hurt_box: HurtBox


func _enter() -> void:
	Level.get_instance().stop_music()
	player.collision_mask = 0
	player.z_index = player.death_z_index
	player.z_as_relative = false
	if LevelCamera.get_instance()._anchor == player:
		LevelCamera.get_instance()._target_zoom = player.death_camera_zoom
	
	Level.get_active_area().process_mode = Node.PROCESS_MODE_DISABLED
	Level.get_active_area().set_process(false)
	Level.get_active_area().set_physics_process(false)
	
	player.disable()
	hurt_box.stop_blink()
	hurt_box.queue_free()
	LevelCamera.get_instance().shake(player.death_shake_strength, player.death_shake_time)


func _next() -> StringName:
	return &"DeathFall" if time >= player.death_fall_delay else &""
