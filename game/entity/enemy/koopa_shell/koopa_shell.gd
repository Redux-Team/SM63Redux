class_name KoopaShell
extends Entity

const SPIN_SPEED_DIVISOR: float = 60.0
const STOP_THRESHOLD: float = 4.0
const KICK_SPEED: float = 300.0


@export var sfx_player: AudioStreamPlayer2D
@export var hurt_box_r: HurtBox


func _physics_process(delta: float) -> void:
	if is_on_wall():
		velocity.x *= -1
	
	# Otherwise it will take a million years to fully stop
	if absf(velocity.x) <= STOP_THRESHOLD:
		velocity.x = 0.0
	
	sprite.speed_scale = absf(velocity.x / SPIN_SPEED_DIVISOR)
	
	super(delta)


func _on_hurt_box_damaged(source_hitbox: HitBox, source_hurtbox: HurtBox) -> void:
	if not sprite.playing:
		sprite.play("spin")
	
	sfx_player.play()
	velocity.x = KICK_SPEED * (-1.0 if source_hurtbox == hurt_box_r else 1.0)
	source_hitbox.bounce_squisher()
