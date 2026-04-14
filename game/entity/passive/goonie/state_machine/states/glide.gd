extends State


func _physics_process(_delta: float) -> void:
	var goonie: Goonie = entity as Goonie
	goonie.velocity.x = goonie.speed * goonie.glide_x_boost * cos(deg_to_rad(goonie.glide_angle))
	goonie.velocity.y = goonie.speed * sin(deg_to_rad(goonie.glide_angle))
