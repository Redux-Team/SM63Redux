extends State

var run_time: float = 0.0
var slowdown_time: float = 0.0
var prev_velocity_sign: float = 0.0
var captured_velocity: float = 0.0


func _physics_process(delta: float) -> void:
	var slowing_down: bool = abs(player.move_dir) < 0.1
	var direction_changed: bool = sign(player.move_dir) != 0.0 and sign(player.move_dir) != prev_velocity_sign and abs(player.velocity.x) > 0.1
	
	if player.is_running and not slowing_down and not direction_changed:
		slowdown_time = 0.0
		player.velocity.x = player.move_dir * player.run_speedup.sample(run_time) * player.run_max_speed
		run_time += delta
	else:
		run_time = 0.0
		
		if slowing_down or direction_changed:
			if slowdown_time == 0.0:
				captured_velocity = player.velocity.x
			
			var slowdown_factor: float = player.run_slowdown.sample(slowdown_time)
			player.velocity.x = captured_velocity * slowdown_factor
			slowdown_time += delta * player.turn_speed
			
			if abs(player.velocity.x) < 0.1:
				slowdown_time = 0.0
		else:
			slowdown_time = 0.0
	
	if abs(player.velocity.x) > 0.1:
		prev_velocity_sign = sign(player.velocity.x)
	
	if player.velocity.x == 0:
		player.is_running = false
