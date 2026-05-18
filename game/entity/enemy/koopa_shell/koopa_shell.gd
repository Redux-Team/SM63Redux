class_name KoopaShell
extends Entity

const VELOCITY_MAP: float = 60.0


@export var audio_stream_player_2d: AudioStreamPlayer2D
@export var hurt_box_r: HurtBox


func _physics_process(delta: float) -> void:
	if is_on_wall():
		velocity.x *= -1
	
	# Otherwise it will take a million years to fully stop
	if abs(velocity.x) <= 4:
		velocity.x = 0
	
	sprite.speed_scale = abs((velocity.x) / VELOCITY_MAP)
	
	super(delta)


func _on_hurt_box_damaged(source_hitbox: HitBox, source_hurtbox: HurtBox) -> void:
	if not sprite.playing:
		sprite.play("spin")
	
	audio_stream_player_2d.play()
	
	velocity.x = 300 * (-1 if source_hurtbox == hurt_box_r else 1)
	
	if source_hitbox.damage_type == HitBox.DamageType.SQUISH and source_hitbox.owner is Player and not source_hitbox.owner.is_on_floor():
		source_hitbox.owner.velocity.y = -200
