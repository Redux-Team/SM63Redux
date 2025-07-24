extends State

var jump_started: bool = false
var jump_completed: bool = false
var jump_time: float = 0.0


func _on_enter(_from: StringName) -> void:
	jump_started = true
	jump_completed = false
	jump_time = 0.0


func _physics_process(delta: float) -> void:
	if jump_started and not jump_completed:
		if jump_time >= player.min_jump_time and not Input.is_action_pressed(&"jump"):
			jump_completed = true
		elif jump_time >= player.max_jump_time:
			jump_completed = true
		
		if not jump_completed:
			player.velocity.y = -player.jump_curve.sample(jump_time)
		
		jump_time += delta
	
	if jump_completed:
		if player.is_on_floor():
			jump_started = false
			jump_completed = false
			jump_time = 0.0
