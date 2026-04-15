extends StateProcess

func _on_ride_area_body_entered(body: Node2D) -> void:
	if body and body != owner and body is Entity:
		owner.bodies.set(body, true)


func _on_ride_area_body_exited(body: Node2D) -> void:
	owner.bodies.erase(body)
