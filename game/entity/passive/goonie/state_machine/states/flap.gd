extends State


func _physics_process(_delta: float) -> void:
	var goonie: Goonie = entity as Goonie
	goonie.velocity.x = goonie.speed * cos(deg_to_rad(goonie.flap_angle))
	goonie.velocity.y = -goonie.speed * sin(deg_to_rad(goonie.flap_angle))
