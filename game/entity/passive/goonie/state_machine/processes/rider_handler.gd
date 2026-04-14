extends StateProcess

func _on_ride_area_body_entered(body: Node2D) -> void:
	if body and body != owner and body is Entity:
		owner.riders.set(body, true)
		print(owner.riders)


func _on_ride_area_body_exited(body: Node2D) -> void:
	owner.riders.erase(body)
	print(owner.riders)
