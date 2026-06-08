@tool
extends State

@export var hurt_box: HurtBox


func _on_enter() -> void:
	Level.get_instance().music_player.stop()
	player.collision_mask = 0
	player.z_index = 10
	player.z_as_relative = false
	if LevelCamera.get_instance()._anchor == player:
		LevelCamera.get_instance()._target_zoom = 2.0
	
	Level.get_active_area().process_mode = Node.PROCESS_MODE_DISABLED
	Level.get_active_area().set_process(false)
	Level.get_active_area().set_physics_process(false)
	
	player.disable()
	hurt_box.stop_blink()
	hurt_box.queue_free()
	LevelCamera.get_instance().shake(40, 0.2)
