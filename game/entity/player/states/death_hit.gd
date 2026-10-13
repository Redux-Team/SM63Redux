extends PlayerState

## Hurtbox removed when the player dies.
@export var hurt_box: HurtBox
## Draw order given to the player so the death plays above the level.
@export var z_index: int = 10
## Time frozen on the hit before falling.
@export_custom(PROPERTY_HINT_NONE, "suffix:s") var fall_delay: float = 1.0


func _enter() -> void:
	player.collision_mask = 0
	player.z_index = z_index
	player.z_as_relative = false
	player.disable()
	hurt_box.stop_blink()
	hurt_box.queue_free()


func _next() -> StringName:
	return &"DeathFall" if time >= fall_delay else &""
